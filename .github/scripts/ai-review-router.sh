#!/usr/bin/env bash
set -euo pipefail

OWNER="${OWNER:-}"
ROUTED_AUTHOR="${ROUTED_AUTHOR:-blixten85}"
REPOSITORY_FILTER="${REPOSITORY_FILTER:-}"
DRY_RUN="${DRY_RUN:-false}"
REVIEW_RESPONSE_TIMEOUT_SECONDS="${REVIEW_RESPONSE_TIMEOUT_SECONDS:-120}"
REVIEW_RESPONSE_POLL_SECONDS="${REVIEW_RESPONSE_POLL_SECONDS:-15}"

primary_labels=(review:coderabbit review:copilot review:codex)
level_labels=(review:level:normal review:level:elevated review:level:deep)

has_label() {
  local labels="$1" wanted="$2"
  grep -Fxq "$wanted" <<< "$labels"
}

ensure_labels() {
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

  ensure_label review:pending FBCB04 "Queue this pull request for a fresh advisory AI review"
  ensure_label review:coderabbit 0E8A16 "Primary advisory review assigned to CodeRabbit"
  ensure_label review:copilot 0969DA "Primary advisory review assigned to GitHub Copilot"
  ensure_label review:codex 5319E7 "Primary advisory review assigned to Codex"
  ensure_label review:deep B60205 "Force the deeper Codex-first advisory review path"
  ensure_label review:level:normal C5DEF5 "Deterministic review level: normal"
  ensure_label review:level:elevated FBCA04 "Deterministic review level: elevated"
  ensure_label review:level:deep D93F0B "Deterministic review level: deep"
}

classify_change_tsv() {
  local rows="$1"
  local path additions deletions
  local files=0 changed_lines=0 level="normal"

  while IFS=$'\t' read -r path additions deletions; do
    [[ -z "$path" ]] && continue
    additions="${additions:-0}"
    deletions="${deletions:-0}"
    ((files += 1))
    ((changed_lines += additions + deletions))

    if [[ "$path" =~ (^|/)(migrations?|schema)(/|$|\.) ]] \
      || [[ "$path" =~ (^|/)(security|permissions?|authorization|authz)(/|$|\.) ]] \
      || [[ "$path" =~ (^|/)(deploy|deployment|infrastructure|infra|terraform|rulesets?)(/|$|\.) ]] \
      || [[ "$path" == "wrangler.toml" || "$path" == */wrangler.toml ]]; then
      level="deep"
      continue
    fi

    if [[ "$level" == "normal" ]]; then
      if [[ "$path" == .github/workflows/* ]] \
        || [[ "$path" =~ (^|/)(auth|authentication|login|oauth|oidc|totp|session)(/|$|\.) ]] \
        || [[ "$path" =~ (^|/)(api|server|backend|database|db|d1|sql)(/|$|\.) ]] \
        || [[ "$path" =~ (^|/)(package(-lock)?\.json|pnpm-lock\.yaml|yarn\.lock|pyproject\.toml|poetry\.lock|requirements[^/]*\.txt|go\.(mod|sum)|Cargo\.(toml|lock)|Dockerfile|compose\.ya?ml|docker-compose\.ya?ml)$ ]]; then
        level="elevated"
      fi
    fi
  done <<< "$rows"

  if (( changed_lines >= 800 || files >= 25 )); then
    level="deep"
  elif [[ "$level" == "normal" ]] && (( changed_lines >= 250 || files >= 10 )); then
    level="elevated"
  fi

  printf '%s\n' "$level"
}

effective_level_for_labels() {
  local classified_level="$1" labels="$2"

  # review:level:deep may be set by the binding deep-gate reconciler. Once
  # present, the advisory router must never downgrade it from file heuristics.
  if has_label "$labels" review:deep || has_label "$labels" review:level:deep; then
    printf 'deep\n'
  else
    printf '%s\n' "$classified_level"
  fi
}

actor_matches_bot() {
  local bot="$1" actor="${2,,}"
  case "$bot" in
    coderabbit)
      [[ "$actor" == "coderabbitai" || "$actor" == "coderabbitai[bot]" ]]
      ;;
    copilot)
      [[ "$actor" == "copilot" || "$actor" == "copilot-pull-request-reviewer[bot]" ]]
      ;;
    codex)
      [[ "$actor" == "chatgpt-codex-connector[bot]" || "$actor" == "codex" || "$actor" == "codex[bot]" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

body_signals_unavailable() {
  local bot="$1" body="${2,,}"
  case "$bot" in
    coderabbit)
      [[ "$body" == *"review skipped"* || "$body" == *"rate limit"* || "$body" == *"usage limit"* || "$body" == *"quota"* ]]
      ;;
    copilot)
      [[ "$body" == *"unable to review"* || "$body" == *"could not review"* || "$body" == *"couldn't review"* || "$body" == *"usage limit"* || "$body" == *"quota"* ]]
      ;;
    codex)
      [[ "$body" == *"usage limit"* || "$body" == *"usage limits"* || "$body" == *"quota"* || "$body" == *"add credits"* ]]
      ;;
    *)
      return 1
      ;;
  esac
}

activity_state_from_tsv() {
  local bot="$1" since="$2"
  local timestamp actor body saw=false

  while IFS=$'\t' read -r timestamp actor body; do
    [[ -z "$timestamp" || -z "$actor" ]] && continue
    [[ "$timestamp" < "$since" ]] && continue
    if ! actor_matches_bot "$bot" "$actor"; then
      continue
    fi
    if body_signals_unavailable "$bot" "${body:-}"; then
      echo unavailable
      return 0
    fi
    saw=true
  done

  if [[ "$saw" == "true" ]]; then
    echo acknowledged
  else
    echo none
  fi
}

collect_bot_activity_rows() {
  local repository="$1" pr="$2"

  gh api --paginate "repos/$repository/issues/$pr/comments?per_page=100" \
    --jq '.[] | [.created_at, .user.login, (.body // "")] | @tsv' 2>/dev/null || true
  gh api --paginate "repos/$repository/pulls/$pr/reviews?per_page=100" \
    --jq '.[] | [.submitted_at, .user.login, (.body // "")] | @tsv' 2>/dev/null || true
  gh api --paginate "repos/$repository/pulls/$pr/comments?per_page=100" \
    --jq '.[] | [.created_at, .user.login, (.body // "")] | @tsv' 2>/dev/null || true
}

bot_activity_state() {
  local repository="$1" pr="$2" bot="$3" since="$4"
  collect_bot_activity_rows "$repository" "$pr" | activity_state_from_tsv "$bot" "$since"
}

wait_for_bot_response() {
  local repository="$1" pr="$2" bot="$3" since="$4"
  local deadline now state
  deadline=$(( $(date +%s) + REVIEW_RESPONSE_TIMEOUT_SECONDS ))

  while true; do
    state="$(bot_activity_state "$repository" "$pr" "$bot" "$since")"
    if [[ "$state" != "none" ]]; then
      echo "$state"
      return 0
    fi

    now="$(date +%s)"
    if (( now >= deadline )); then
      echo timeout
      return 0
    fi
    sleep "$REVIEW_RESPONSE_POLL_SECONDS"
  done
}

has_bot_review() {
  local repository="$1" pr="$2" bot="$3"
  local actor
  while IFS= read -r actor; do
    if actor_matches_bot "$bot" "$actor"; then
      return 0
    fi
  done < <(
    gh api --paginate "repos/$repository/pulls/$pr/reviews?per_page=100" \
      --jq '.[].user.login' 2>/dev/null || true
  )
  return 1
}

has_copilot_review_or_request() {
  local repository="$1" pr="$2"
  if has_bot_review "$repository" "$pr" copilot; then
    return 0
  fi

  gh api "repos/$repository/pulls/$pr/requested_reviewers" \
    --jq '.users[].login' 2>/dev/null \
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
      # Adding review:coderabbit is the request. The label is selected before
      # this function runs so CodeRabbit can react without a command comment.
      return 0
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

select_primary_route() {
  local repository="$1" pr="$2" bot="$3" force_reapply="${4:-false}"
  local selected="review:$bot" labels label
  labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would select $selected for $repository#$pr"
    return 0
  fi

  for label in "${primary_labels[@]}"; do
    if has_label "$labels" "$label" && { [[ "$label" != "$selected" ]] || [[ "$force_reapply" == "true" ]]; }; then
      gh pr edit "$pr" --repo "$repository" --remove-label "$label" >/dev/null
    fi
  done

  if [[ "$force_reapply" == "true" ]] || ! has_label "$labels" "$selected"; then
    gh pr edit "$pr" --repo "$repository" --add-label "$selected" >/dev/null
  fi
}

finalize_route() {
  local repository="$1" pr="$2"
  local labels
  labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would clear review:pending for $repository#$pr"
    return 0
  fi

  if has_label "$labels" review:pending; then
    gh pr edit "$pr" --repo "$repository" --remove-label review:pending >/dev/null
  fi
}

clear_primary_routes() {
  local repository="$1" pr="$2"
  local labels label
  labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would clear primary review labels for $repository#$pr"
    return 0
  fi

  for label in "${primary_labels[@]}"; do
    if has_label "$labels" "$label"; then
      gh pr edit "$pr" --repo "$repository" --remove-label "$label" >/dev/null
    fi
  done
}

mark_level() {
  local repository="$1" pr="$2" level="$3" current_labels="$4"
  local selected current="" label

  level="$(effective_level_for_labels "$level" "$current_labels")"
  selected="review:level:$level"

  for label in "${level_labels[@]}"; do
    if has_label "$current_labels" "$label"; then
      current="$label"
      break
    fi
  done

  if [[ "$current" == "$selected" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would set $repository#$pr level to $level"
    return 0
  fi

  if [[ -n "$current" ]]; then
    gh pr edit "$pr" --repo "$repository" --remove-label "$current" >/dev/null
  fi
  gh pr edit "$pr" --repo "$repository" --add-label "$selected" >/dev/null
}

mark_pending() {
  local repository="$1" pr="$2"
  local labels
  labels="$(gh api "repos/$repository/issues/$pr" --jq '.labels[].name')"

  if has_label "$labels" review:pending; then
    return 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would label $repository#$pr with review:pending"
    return 0
  fi
  gh pr edit "$pr" --repo "$repository" --add-label review:pending >/dev/null
}

bot_chain_for_level() {
  local level="$1"
  if [[ "$level" == "deep" ]]; then
    echo "codex coderabbit copilot"
  else
    echo "coderabbit copilot codex"
  fi
}

route_candidate() {
  local line="$1"
  local created repository pr level fresh requested_at state bot
  IFS=$'\t' read -r created repository pr level fresh <<< "$line"

  echo "Routing $repository#$pr (created $created, level $level, fresh=$fresh)."

  # Keep review:pending while a request is in flight. If the workflow is
  # interrupted, the next scheduled run will safely pick the PR up again.
  mark_pending "$repository" "$pr"

  for bot in $(bot_chain_for_level "$level"); do
    if [[ "$fresh" != "true" ]] && has_bot_review "$repository" "$pr" "$bot"; then
      echo "Adopting existing $bot review for $repository#$pr."
      select_primary_route "$repository" "$pr" "$bot" false
      finalize_route "$repository" "$pr"
      return 0
    fi

    # Capture the time before selecting the label so a fast CodeRabbit status
    # comment emitted by the label event cannot be missed by the response poll.
    requested_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if ! select_primary_route "$repository" "$pr" "$bot" "$fresh"; then
      echo "::warning::Could not select $bot for $repository#$pr; trying fallback."
      continue
    fi
    if ! trigger_review "$repository" "$pr" "$bot"; then
      echo "::warning::Could not request $bot review for $repository#$pr; trying fallback."
      continue
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      finalize_route "$repository" "$pr"
      return 0
    fi

    state="$(wait_for_bot_response "$repository" "$pr" "$bot" "$requested_at")"
    case "$state" in
      acknowledged)
        echo "$bot acknowledged $repository#$pr."
        finalize_route "$repository" "$pr"
        return 0
        ;;
      unavailable)
        echo "::warning::$bot reported itself unavailable for $repository#$pr; trying fallback."
        ;;
      timeout)
        echo "::warning::$bot did not respond within ${REVIEW_RESPONSE_TIMEOUT_SECONDS}s for $repository#$pr; trying fallback."
        ;;
      *)
        echo "::warning::Unexpected response state '$state' from $bot for $repository#$pr; trying fallback."
        ;;
    esac
  done

  echo "::warning::No review bot acknowledged $repository#$pr; keeping it pending for a later run."
  clear_primary_routes "$repository" "$pr"
  mark_pending "$repository" "$pr"
  return 1
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

  local candidates="$RUNNER_TEMP/review-candidates.tsv"
  : > "$candidates"

  local repository human_prs pr created login _type labels pending primary manual_deep level files_tsv fresh
  for repository in "${repositories[@]}"; do
    human_prs="$RUNNER_TEMP/${repository//\//_}-prs.tsv"
    : > "$human_prs"

    while IFS=$'\t' read -r pr created login _type; do
      [[ -z "$pr" ]] && continue
      if [[ "$_type" == "Bot" || "$login" == *"[bot]" ]]; then
        continue
      fi
      printf '%s\t%s\t%s\t%s\n' "$pr" "$created" "$login" "$_type" >> "$human_prs"
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
      manual_deep=false

      if has_label "$labels" review:pending; then
        pending=true
      fi
      if has_label "$labels" review:deep; then
        manual_deep=true
      fi
      for label in "${primary_labels[@]}"; do
        if has_label "$labels" "$label"; then
          primary=true
          break
        fi
      done

      # Conserve review quota by routing the owner's PRs automatically. Other human
      # contributors can opt in explicitly with review:pending or review:deep.
      if [[ "$login" != "$ROUTED_AUTHOR" && "$pending" != "true" && "$manual_deep" != "true" ]]; then
        continue
      fi

      files_tsv="$(
        gh api --paginate "repos/$repository/pulls/$pr/files?per_page=100" \
          --jq '.[] | [.filename, .additions, .deletions] | @tsv'
      )"
      level="$(effective_level_for_labels "$(classify_change_tsv "$files_tsv")" "$labels")"
      mark_level "$repository" "$pr" "$level" "$labels"

      if [[ "$primary" == "true" && "$pending" != "true" ]]; then
        continue
      fi

      # Adopt an existing CodeRabbit review for normal/elevated PRs, or an existing
      # Codex review for deep PRs, instead of spending a fresh request.
      if [[ "$pending" != "true" ]]; then
        if [[ "$level" == "deep" ]] && has_bot_review "$repository" "$pr" codex; then
          echo "Adopting existing Codex review for $repository#$pr."
          select_primary_route "$repository" "$pr" codex false
          finalize_route "$repository" "$pr"
          continue
        fi
        if [[ "$level" != "deep" ]] && has_bot_review "$repository" "$pr" coderabbit; then
          echo "Adopting existing CodeRabbit review for $repository#$pr."
          select_primary_route "$repository" "$pr" coderabbit false
          finalize_route "$repository" "$pr"
          continue
        fi
      fi

      fresh=false
      if [[ "$pending" == "true" ]]; then
        fresh=true
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$created" "$repository" "$pr" "$level" "$fresh" >> "$candidates"
    done < "$human_prs"
  done

  if [[ ! -s "$candidates" ]]; then
    echo "No unrouted pull requests found."
    exit 0
  fi

  # One scheduled candidate per run keeps CodeRabbit requests bounded to at most
  # eight per clock hour. Fallbacks happen inside the same run only when the
  # selected bot does not acknowledge within the response window or reports
  # itself unavailable.
  sort -t $'\t' -k1,1 "$candidates" -o "$candidates"
  route_candidate "$(head -n 1 "$candidates")" || true
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
