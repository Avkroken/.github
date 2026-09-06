#!/usr/bin/env bash
set -euo pipefail

OWNER="${OWNER:-}"
REPOSITORY_FILTER="${REPOSITORY_FILTER:-}"
DRY_RUN="${DRY_RUN:-false}"

waiting_label="review:coderabbit-waiting"
# HEAD-bound CodeRabbit activity older than this window no longer suppresses a retry.
pending_review_retry_after_seconds=1800

has_label() {
  local labels="$1" wanted="$2"
  grep -Fxq "$wanted" <<< "$labels"
}

actor_is_coderabbit() {
  local actor="${1,,}"
  [[ "$actor" == "coderabbitai" || "$actor" == "coderabbitai[bot]" ]]
}

review_state_is_submitted() {
  case "$1" in
    APPROVED|CHANGES_REQUESTED|COMMENTED)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

coderabbit_activity_is_fresh() {
  local activity_created_at="$1" now_epoch="$2" activity_epoch age_seconds

  [[ "$activity_created_at" != "-" ]] || return 1
  if ! activity_epoch="$(date --date="$activity_created_at" +%s 2>/dev/null)"; then
    return 1
  fi
  age_seconds=$(( now_epoch - activity_epoch ))
  (( age_seconds >= 0 && age_seconds < pending_review_retry_after_seconds ))
}

critical_central_path() {
  local path="$1"
  case "$path" in
    AGENTS.md|GITHUB.md|.coderabbit.yaml|\
    .github/workflows/ai-review-router.yml|\
    .github/workflows/dependabot-automerge.yml|\
    .github/workflows/governance-drift-audit.yml|\
    .github/workflows/issue-classification.lock.yml|\
    .github/workflows/metadata-orchestration.yml|\
    .github/workflows/metadata-routing.yml|\
    .github/workflows/osv-scanner.yml|\
    .github/workflows/reconcile-reusable-workflow-pins.yml|\
    .github/workflows/release-please.yml|\
    .github/workflows/sync-reusable-workflow-pins.yml|\
    .github/scripts/ai-review-router.sh|\
    .github/scripts/ai-review-router.test.sh|\
    .github/scripts/deep-coderabbit-gate.sh|\
    .github/scripts/deep-coderabbit-gate.test.sh)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Returns 0 when critical, 1 when non-critical, and 2 when the GitHub listing
# cannot be trusted. Callers must propagate status 2 rather than treating it as
# a non-critical result.
central_pr_is_critical() {
  local repository="$1" pr="$2"
  [[ "$repository" == "$OWNER/.github" ]] || return 1

  local paths path
  if ! paths="$(
    gh api --paginate "repos/$repository/pulls/$pr/files?per_page=100" \
      --jq '.[].filename'
  )"; then
    echo "::error::Could not list changed files for $repository#$pr; refusing to classify it as non-critical." >&2
    return 2
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if critical_central_path "$path"; then
      return 0
    fi
  done <<< "$paths"
  return 1
}

# Input rows are TSV: kind, actor, commit SHA/sentinel, review state/sentinel,
# observable activity time/sentinel, body. For comments the timestamp is the
# CodeRabbit status comment's created_at. Review timestamps are never used to
# age a PENDING review because GitHub does not expose a reliable start time for
# that state. Sentinels keep intermediate fields non-empty because Bash treats
# tab as IFS whitespace and otherwise collapses adjacent empty fields.
coderabbit_gate_state_from_tsv() {
  local head_sha="$1"
  local now_epoch="${2:-$(date +%s)}"
  local kind actor commit_sha review_state activity_created_at body
  local saw_in_progress=false

  while IFS=$'\t' read -r kind actor commit_sha review_state activity_created_at body; do
    [[ -n "$actor" ]] || continue
    actor_is_coderabbit "$actor" || continue

    if [[ "$kind" == "review" && "$commit_sha" == "$head_sha" ]]; then
      if review_state_is_submitted "$review_state"; then
        echo complete
        return 0
      fi
    fi

    if [[ "$kind" == "comment" ]]; then
      if [[ "$body" == *"\"coveredCommitId\":\"$head_sha\""* \
        && "$body" == *'"kind":"reviewed"'* ]]; then
        echo complete
        return 0
      fi

      if [[ "$body" == *"review in progress by coderabbit.ai"* \
        && "$body" == *"$head_sha"* ]]; then
        if coderabbit_activity_is_fresh "$activity_created_at" "$now_epoch"; then
          saw_in_progress=true
        fi
      fi
    fi
  done

  if [[ "$saw_in_progress" == "true" ]]; then
    echo in_progress
  else
    # Missing also intentionally covers skipped/quota/unavailable responses and
    # orphaned/stale PENDING reviews without fresh observable HEAD activity.
    echo missing
  fi
}

collect_coderabbit_gate_rows() {
  local repository="$1" pr="$2"
  local repository_owner="${repository%%/*}" repository_name="${repository#*/}"

  if ! gh api --paginate "repos/$repository/issues/$pr/comments?per_page=100" \
    --jq '.[] | ["comment", .user.login, "-", "-", (.created_at // "-"), (.body // "")] | @tsv'; then
    echo "::error::Could not list issue comments for CodeRabbit gate on $repository#$pr." >&2
    return 1
  fi
  if ! gh api graphql --paginate \
    -f query='query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviews(first: 100, after: $endCursor) {
            nodes {
              author { login }
              body
              commit { oid }
              createdAt
              state
            }
            pageInfo { hasNextPage endCursor }
          }
        }
      }
    }' \
    -f owner="$repository_owner" \
    -f name="$repository_name" \
    -F number="$pr" \
    --jq '.data.repository.pullRequest.reviews.nodes[] | ["review", (.author.login // "-"), (.commit.oid // "-"), (.state // "-"), (.createdAt // "-"), (.body // "")] | @tsv'; then
    echo "::error::Could not list pull-request reviews for CodeRabbit gate on $repository#$pr." >&2
    return 1
  fi
}

coderabbit_gate_state() {
  local repository="$1" pr="$2" head_sha="$3"
  collect_coderabbit_gate_rows "$repository" "$pr" \
    | coderabbit_gate_state_from_tsv "$head_sha"
}

ensure_repository_labels() {
  local repository="$1"
  local existing
  existing="$(gh label list --repo "$repository" --limit 1000 --json name --jq '.[].name')"

  ensure_label() {
    local name="$1" color="$2" description="$3"
    if grep -Fxq "$name" <<< "$existing"; then
      return 0
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] would create label $repository:$name"
      return 0
    fi
    gh label create "$name" --repo "$repository" --color "$color" --description "$description"
    existing+=$'\n'"$name"
  }

  ensure_label review:coderabbit 0E8A16 "Primary advisory review assigned to CodeRabbit"
  ensure_label "$waiting_label" D93F0B "Deep CodeRabbit gate is waiting for latest-HEAD coverage"
  ensure_label review:level:normal C5DEF5 "Deterministic review level: normal"
  ensure_label review:level:elevated FBCA04 "Deterministic review level: elevated"
  ensure_label review:level:deep D93F0B "Deterministic review level: deep"
}

set_central_deep_level() {
  local repository="$1" pr="$2" labels="$3"
  local label

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would mark $repository#$pr review:level:deep"
    return 0
  fi

  for label in review:level:normal review:level:elevated; do
    if has_label "$labels" "$label"; then
      gh pr edit "$pr" --repo "$repository" --remove-label "$label" >/dev/null
    fi
  done
  if ! has_label "$labels" review:level:deep; then
    gh pr edit "$pr" --repo "$repository" --add-label review:level:deep >/dev/null
  fi
}

ensure_coderabbit_primary() {
  local repository="$1" pr="$2" labels="$3" reapply="${4:-false}"
  local label

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would select review:coderabbit for $repository#$pr (reapply=$reapply)"
    return 0
  fi

  for label in review:copilot review:codex; do
    if has_label "$labels" "$label"; then
      gh pr edit "$pr" --repo "$repository" --remove-label "$label" >/dev/null
    fi
  done

  if [[ "$reapply" == "true" ]] && has_label "$labels" review:coderabbit; then
    gh pr edit "$pr" --repo "$repository" --remove-label review:coderabbit >/dev/null
  fi
  if [[ "$reapply" == "true" ]] || ! has_label "$labels" review:coderabbit; then
    gh pr edit "$pr" --repo "$repository" --add-label review:coderabbit >/dev/null
  fi
}

mark_waiting() {
  local repository="$1" pr="$2" labels="$3"
  if has_label "$labels" "$waiting_label"; then
    return 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would mark $repository#$pr with $waiting_label"
    return 0
  fi
  gh pr edit "$pr" --repo "$repository" --add-label "$waiting_label" >/dev/null
}

clear_waiting() {
  local repository="$1" pr="$2" labels="$3"
  if ! has_label "$labels" "$waiting_label"; then
    return 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would clear $waiting_label from $repository#$pr"
    return 0
  fi
  gh pr edit "$pr" --repo "$repository" --remove-label "$waiting_label" >/dev/null
}

main() {
  if [[ -z "$OWNER" ]]; then
    echo "::error::OWNER is required"
    exit 1
  fi
  if [[ -n "$REPOSITORY_FILTER" && "$REPOSITORY_FILTER" != "$OWNER/"* ]]; then
    echo "::error::repository filter must be inside $OWNER"
    exit 1
  fi

  local repositories=()
  if [[ -n "$REPOSITORY_FILTER" ]]; then
    repositories=("$REPOSITORY_FILTER")
  else
    local repository_listing repository
    if ! repository_listing="$(
      gh api --paginate "installation/repositories?per_page=100" \
        --jq '.repositories[] | select(.archived == false and .fork == false) | .full_name'
    )"; then
      echo "::error::Could not list installation repositories; refusing to report deep gates reconciled." >&2
      return 1
    fi
    while IFS= read -r repository; do
      [[ -n "$repository" ]] && repositories+=("$repository")
    done <<< "$repository_listing"
  fi

  local retry_candidates="$RUNNER_TEMP/deep-coderabbit-retries.tsv"
  : > "$retry_candidates"

  local repository pr created head_sha labels is_deep state critical_status pr_listing row
  for repository in "${repositories[@]}"; do
    local prs=()
    if ! pr_listing="$(
      gh api --paginate "repos/$repository/pulls?state=open&per_page=100" \
        --jq '.[] | [.number, .created_at, .head.sha] | @tsv'
    )"; then
      echo "::error::Could not list open pull requests for $repository; refusing partial deep-gate reconciliation." >&2
      return 1
    fi
    while IFS= read -r row; do
      [[ -n "$row" ]] && prs+=("$row")
    done <<< "$pr_listing"
    (( ${#prs[@]} > 0 )) || continue

    ensure_repository_labels "$repository"

    for row in "${prs[@]}"; do
      IFS=$'\t' read -r pr created head_sha <<< "$row"
      [[ -n "$pr" && -n "$head_sha" ]] || continue

      labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"
      is_deep=false
      if has_label "$labels" review:deep || has_label "$labels" review:level:deep; then
        is_deep=true
      elif central_pr_is_critical "$repository" "$pr"; then
        is_deep=true
        set_central_deep_level "$repository" "$pr" "$labels"
        labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"
      else
        critical_status=$?
        if (( critical_status != 1 )); then
          return "$critical_status"
        fi
      fi

      [[ "$is_deep" == "true" ]] || continue

      state="$(coderabbit_gate_state "$repository" "$pr" "$head_sha")"
      case "$state" in
        complete)
          echo "Deep CodeRabbit gate satisfied for $repository#$pr at $head_sha."
          ensure_coderabbit_primary "$repository" "$pr" "$labels" false
          clear_waiting "$repository" "$pr" "$labels"
          ;;
        in_progress)
          echo "CodeRabbit is already reviewing latest HEAD for $repository#$pr; keeping gate waiting without retriggering."
          ensure_coderabbit_primary "$repository" "$pr" "$labels" false
          mark_waiting "$repository" "$pr" "$labels"
          ;;
        missing)
          echo "Deep CodeRabbit gate is missing latest-HEAD coverage for $repository#$pr; scheduling retry."
          mark_waiting "$repository" "$pr" "$labels"
          printf '%s\t%s\t%s\t%s\n' "$created" "$repository" "$pr" "$head_sha" >> "$retry_candidates"
          ;;
        *)
          echo "::warning::Unexpected CodeRabbit gate state '$state' for $repository#$pr; leaving it waiting."
          mark_waiting "$repository" "$pr" "$labels"
          ;;
      esac
    done
  done

  if [[ ! -s "$retry_candidates" ]]; then
    echo "No deep CodeRabbit retry is needed."
    exit 0
  fi

  # Re-trigger at most one deep PR per scheduled run. Re-read all mutable state
  # before doing so because CodeRabbit or the PR can change during the org sweep.
  sort -t $'\t' -k1,1 "$retry_candidates" -o "$retry_candidates"
  local selected pr_json pr_fields current_state current_head
  selected="$(head -n1 "$retry_candidates")"
  IFS=$'\t' read -r created repository pr head_sha <<< "$selected"

  if ! pr_json="$(gh api "repos/$repository/pulls/$pr")"; then
    echo "::error::Could not refresh retry candidate $repository#$pr." >&2
    return 1
  fi
  if ! pr_fields="$(jq -r '[.state, .head.sha] | @tsv' <<< "$pr_json")"; then
    echo "::error::Could not parse refreshed retry candidate $repository#$pr." >&2
    return 1
  fi
  IFS=$'\t' read -r current_state current_head <<< "$pr_fields"
  if [[ "$current_state" != "open" ]]; then
    echo "Skipping stale retry candidate $repository#$pr: PR is now $current_state."
    return 0
  fi

  labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"
  is_deep=false
  if has_label "$labels" review:deep || has_label "$labels" review:level:deep; then
    is_deep=true
  elif central_pr_is_critical "$repository" "$pr"; then
    is_deep=true
    set_central_deep_level "$repository" "$pr" "$labels"
    labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"
  else
    critical_status=$?
    if (( critical_status != 1 )); then
      return "$critical_status"
    fi
  fi
  if [[ "$is_deep" != "true" ]]; then
    echo "Skipping stale retry candidate $repository#$pr: it is no longer deep."
    return 0
  fi

  state="$(coderabbit_gate_state "$repository" "$pr" "$current_head")"
  case "$state" in
    complete)
      echo "Skipping retry for $repository#$pr: CodeRabbit now covers current HEAD $current_head."
      ensure_coderabbit_primary "$repository" "$pr" "$labels" false
      clear_waiting "$repository" "$pr" "$labels"
      return 0
      ;;
    in_progress)
      echo "Skipping retry for $repository#$pr: CodeRabbit is now reviewing current HEAD $current_head."
      ensure_coderabbit_primary "$repository" "$pr" "$labels" false
      mark_waiting "$repository" "$pr" "$labels"
      return 0
      ;;
    missing)
      echo "Retrying deep CodeRabbit gate for $repository#$pr at refreshed HEAD $current_head."
      mark_waiting "$repository" "$pr" "$labels"
      ensure_coderabbit_primary "$repository" "$pr" "$labels" true
      ;;
    *)
      echo "::error::Unexpected refreshed CodeRabbit gate state '$state' for $repository#$pr." >&2
      return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
