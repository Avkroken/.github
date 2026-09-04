#!/usr/bin/env bash
set -euo pipefail

OWNER="${OWNER:?OWNER is required}"
ROUTED_AUTHOR="${ROUTED_AUTHOR:-blixten85}"
REPOSITORY_FILTER="${REPOSITORY_FILTER:-}"
DRY_RUN="${DRY_RUN:-false}"

primary_labels=(review:coderabbit review:copilot review:codex)

has_label() {
  local labels="$1" wanted="$2"
  grep -Fxq "$wanted" <<< "$labels"
}

ensure_labels() {
  local repository="$1"
  local existing
  existing="$(gh label list --repo "$repository" --limit 500 --json name --jq '.[].name')"

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

  ensure_label review:pending FBCB04 "Queue this pull request for a fresh advisory AI review"
  ensure_label review:coderabbit 0E8A16 "Primary advisory review assigned to CodeRabbit"
  ensure_label review:copilot 0969DA "Primary advisory review assigned to GitHub Copilot"
  ensure_label review:codex 5319E7 "Primary advisory review assigned to Codex"
  ensure_label review:deep B60205 "Prefer Codex for a deeper advisory review"
}

has_coderabbit_review() {
  local repository="$1" pr="$2"
  gh api --paginate "repos/$repository/pulls/$pr/reviews?per_page=100" \
    --jq '.[].user.login' \
    | grep -Eq '^coderabbitai(\[bot\])?$'
}

has_copilot_review_or_request() {
  local repository="$1" pr="$2"
  if gh api --paginate "repos/$repository/pulls/$pr/reviews?per_page=100" \
      --jq '.[].user.login' \
      | grep -Fxq 'copilot-pull-request-reviewer[bot]'; then
    return 0
  fi

  gh api "repos/$repository/pulls/$pr/requested_reviewers" \
    --jq '.users[].login' \
    | grep -Fxq 'copilot-pull-request-reviewer[bot]'
}

trigger_review() {
  local repository="$1" pr="$2" bot="$3"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would request $bot review for $repository#$pr"
    return 0
  fi

  case "$bot" in
    coderabbit)
      gh pr comment "$pr" --repo "$repository" --body '@coderabbitai review' >/dev/null
      ;;
    copilot)
      if has_copilot_review_or_request "$repository" "$pr"; then
        echo "Copilot is already reviewing or has reviewed $repository#$pr."
        return 0
      fi
      jq -n '{reviewers:["copilot-pull-request-reviewer[bot]"]}' \
        | gh api --method POST "repos/$repository/pulls/$pr/requested_reviewers" --input - >/dev/null
      ;;
    codex)
      gh pr comment "$pr" --repo "$repository" --body '@codex review' >/dev/null
      ;;
    *)
      echo "::error::Unsupported review bot: $bot"
      return 1
      ;;
  esac
}

mark_route() {
  local repository="$1" pr="$2" bot="$3" current_labels="$4"
  local selected="review:$bot"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would label $repository#$pr with $selected"
    return 0
  fi

  for label in "${primary_labels[@]}" review:pending; do
    if has_label "$current_labels" "$label"; then
      gh pr edit "$pr" --repo "$repository" --remove-label "$label" >/dev/null
    fi
  done
  gh pr edit "$pr" --repo "$repository" --add-label "$selected" >/dev/null
}

route_candidate() {
  local line="$1" bot="$2"
  local created repository pr mode labels
  IFS=$'\t' read -r created repository pr mode <<< "$line"
  labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"

  echo "Routing $repository#$pr to $bot (created $created, mode $mode)."
  if trigger_review "$repository" "$pr" "$bot"; then
    mark_route "$repository" "$pr" "$bot" "$labels"
    return 0
  fi

  echo "::warning::Could not request $bot review for $repository#$pr; leaving it pending."
  return 1
}

if [[ -n "$REPOSITORY_FILTER" && "$REPOSITORY_FILTER" != "$OWNER/"* ]]; then
  echo "::error::repository filter must be inside $OWNER"
  exit 1
fi

if [[ -n "$REPOSITORY_FILTER" ]]; then
  repositories=("$REPOSITORY_FILTER")
else
  mapfile -t repositories < <(
    gh api --paginate "installation/repositories?per_page=100" \
      --jq '.repositories[] | select(.archived == false and .fork == false) | .full_name'
  )
fi

candidates="$RUNNER_TEMP/review-candidates.tsv"
: > "$candidates"

for repository in "${repositories[@]}"; do
  human_prs="$RUNNER_TEMP/${repository//\//_}-prs.tsv"
  : > "$human_prs"

  while IFS=$'\t' read -r pr created login type; do
    [[ -z "$pr" ]] && continue
    if [[ "$type" == "Bot" || "$login" == *"[bot]" ]]; then
      continue
    fi
    printf '%s\t%s\t%s\t%s\n' "$pr" "$created" "$login" "$type" >> "$human_prs"
  done < <(
    gh api --paginate "repos/$repository/pulls?state=open&per_page=100" \
      --jq '.[] | [.number, .created_at, .user.login, .user.type] | @tsv'
  )

  if [[ ! -s "$human_prs" ]]; then
    continue
  fi

  ensure_labels "$repository"

  while IFS=$'\t' read -r pr created login _type; do
    labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"
    pending=false
    primary=false
    deep=false

    if has_label "$labels" review:pending; then
      pending=true
    fi
    if has_label "$labels" review:deep; then
      deep=true
    fi
    for label in "${primary_labels[@]}"; do
      if has_label "$labels" "$label"; then
        primary=true
        break
      fi
    done

    if [[ "$primary" == "true" && "$pending" != "true" ]]; then
      continue
    fi

    # Conserve review quota by routing the owner's PRs automatically. Other human
    # contributors can opt in explicitly with review:pending or review:deep.
    if [[ "$login" != "$ROUTED_AUTHOR" && "$pending" != "true" && "$deep" != "true" ]]; then
      continue
    fi

    mode=normal
    if [[ "$deep" == "true" ]]; then
      mode=deep
    fi

    # If CodeRabbit already reviewed an otherwise-unrouted PR automatically,
    # adopt that review as the primary one instead of spending another request.
    if [[ "$pending" != "true" && "$mode" == "normal" ]] && has_coderabbit_review "$repository" "$pr"; then
      echo "Adopting existing CodeRabbit review for $repository#$pr."
      mark_route "$repository" "$pr" coderabbit "$labels"
      continue
    fi

    printf '%s\t%s\t%s\t%s\n' "$created" "$repository" "$pr" "$mode" >> "$candidates"
  done < "$human_prs"
done

if [[ ! -s "$candidates" ]]; then
  echo "No unrouted pull requests found."
  exit 0
fi

sort -t $'\t' -k1,1 "$candidates" -o "$candidates"
mapfile -t deep_candidates < <(awk -F '\t' '$4 == "deep"' "$candidates")
mapfile -t normal_candidates < <(awk -F '\t' '$4 == "normal"' "$candidates")

# Deep review is opt-in via review:deep. Limit it to one Codex request per run.
if (( ${#deep_candidates[@]} > 0 )); then
  route_candidate "${deep_candidates[0]}" codex || true
fi

# The workflow runs every eight minutes and sends at most one new CodeRabbit
# request per run, so router-generated CodeRabbit requests are capped at 8/hour.
# If the request itself fails, fall back to Copilot for that PR. Otherwise the
# next normal PR may use Copilot as overflow so a backlog does not wait on
# CodeRabbit alone.
copilot_used=false
if (( ${#normal_candidates[@]} > 0 )); then
  if ! route_candidate "${normal_candidates[0]}" coderabbit; then
    route_candidate "${normal_candidates[0]}" copilot || true
    copilot_used=true
  fi
fi

if [[ "$copilot_used" != "true" && ${#normal_candidates[@]} -gt 1 ]]; then
  route_candidate "${normal_candidates[1]}" copilot || true
fi
