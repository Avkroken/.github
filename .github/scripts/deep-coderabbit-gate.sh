#!/usr/bin/env bash
set -euo pipefail

OWNER="${OWNER:-}"
REPOSITORY_FILTER="${REPOSITORY_FILTER:-}"
DRY_RUN="${DRY_RUN:-false}"

waiting_label="review:coderabbit-waiting"
primary_labels=(review:coderabbit review:copilot review:codex)
level_labels=(review:level:normal review:level:elevated review:level:deep)

has_label() {
  local labels="$1" wanted="$2"
  grep -Fxq "$wanted" <<< "$labels"
}

actor_is_coderabbit() {
  local actor="${1,,}"
  [[ "$actor" == "coderabbitai" || "$actor" == "coderabbitai[bot]" ]]
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

central_pr_is_critical() {
  local repository="$1" pr="$2"
  [[ "$repository" == "$OWNER/.github" ]] || return 1

  local path
  while IFS= read -r path; do
    if critical_central_path "$path"; then
      return 0
    fi
  done < <(
    gh api --paginate "repos/$repository/pulls/$pr/files?per_page=100" \
      --jq '.[].filename'
  )
  return 1
}

# Input rows are TSV: kind, actor, commit SHA, body. A qualifying CodeRabbit
# result is either a formal review anchored to HEAD or a completed CodeRabbit
# artifact/comment whose final-review coverage explicitly names HEAD.
coderabbit_gate_state_from_tsv() {
  local head_sha="$1"
  local kind actor commit_sha body
  local saw_in_progress=false

  while IFS=$'\t' read -r kind actor commit_sha body; do
    [[ -n "$actor" ]] || continue
    actor_is_coderabbit "$actor" || continue

    if [[ "$kind" == "review" && "$commit_sha" == "$head_sha" ]]; then
      echo complete
      return 0
    fi

    if [[ "$kind" == "comment" ]]; then
      if [[ "$body" == *"\"coveredCommitId\":\"$head_sha\""* \
        && "$body" == *'"kind":"reviewed"'* ]]; then
        echo complete
        return 0
      fi

      if [[ "$body" == *"review in progress by coderabbit.ai"* \
        && "$body" == *"$head_sha"* ]]; then
        saw_in_progress=true
      fi
    fi
  done

  if [[ "$saw_in_progress" == "true" ]]; then
    echo in_progress
  else
    # Missing also intentionally covers skipped/quota/unavailable responses.
    # They never satisfy the gate and remain eligible for a later retry.
    echo missing
  fi
}

collect_coderabbit_gate_rows() {
  local repository="$1" pr="$2"

  gh api --paginate "repos/$repository/issues/$pr/comments?per_page=100" \
    --jq '.[] | ["comment", .user.login, "", (.body // "")] | @tsv' 2>/dev/null || true
  gh api --paginate "repos/$repository/pulls/$pr/reviews?per_page=100" \
    --jq '.[] | ["review", .user.login, (.commit_id // ""), (.body // "")] | @tsv' 2>/dev/null || true
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
    mapfile -t repositories < <(
      gh api --paginate "installation/repositories?per_page=100" \
        --jq '.repositories[] | select(.archived == false and .fork == false) | .full_name'
    )
  fi

  local retry_candidates="$RUNNER_TEMP/deep-coderabbit-retries.tsv"
  : > "$retry_candidates"

  local repository pr created head_sha labels is_deep state
  for repository in "${repositories[@]}"; do
    mapfile -t prs < <(
      gh api --paginate "repos/$repository/pulls?state=open&per_page=100" \
        --jq '.[] | [.number, .created_at, .head.sha] | @tsv'
    )
    (( ${#prs[@]} > 0 )) || continue

    ensure_repository_labels "$repository"

    local row
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

  # Re-trigger at most one deep PR per scheduled run. The 8-minute workflow
  # cadence therefore bounds automatic CodeRabbit retry pressure while still
  # recovering automatically after quota, skipped-review, or transient failures.
  sort -t $'\t' -k1,1 "$retry_candidates" -o "$retry_candidates"
  local selected
  selected="$(head -n1 "$retry_candidates")"
  IFS=$'\t' read -r created repository pr head_sha <<< "$selected"
  labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"
  echo "Retrying deep CodeRabbit gate for $repository#$pr at $head_sha."
  ensure_coderabbit_primary "$repository" "$pr" "$labels" true
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
