#!/usr/bin/env bash
set -euo pipefail

repo="${GH_REPO:-Avkroken/.github}"
api_version="2026-03-10"

for path in \
  AGENTS.md \
  .github/workflows/ci.yml \
  .github/workflows/promote-dev.yml \
  .github/workflows/redraft-failed-admission.yml; do
  gh api -H "X-GitHub-Api-Version: $api_version" "repos/$repo/contents/$path?ref=main" >/dev/null
done

main_sha="$(gh api -H "X-GitHub-Api-Version: $api_version" "repos/$repo/git/ref/heads/main" --jq '.object.sha')"

if ! gh api -H "X-GitHub-Api-Version: $api_version" "repos/$repo/git/ref/heads/dev" >/dev/null 2>&1; then
  gh api -H "X-GitHub-Api-Version: $api_version" --method POST "repos/$repo/git/refs" \
    -f ref='refs/heads/dev' \
    -f sha="$main_sha" >/dev/null
  gh api -H "X-GitHub-Api-Version: $api_version" --method POST "repos/$repo/git/refs" \
    -f ref='refs/tags/dev-promoted' \
    -f sha="$main_sha" >/dev/null
elif ! gh api -H "X-GitHub-Api-Version: $api_version" "repos/$repo/git/ref/tags/dev-promoted" >/dev/null 2>&1; then
  echo "dev exists but refs/tags/dev-promoted does not; refusing to guess the promotion baseline" >&2
  exit 1
fi

rulesets="$(gh api -H "X-GitHub-Api-Version: $api_version" "repos/$repo/rulesets?includes_parents=false")"
required_id="$(jq -r '.[] | select(.name == "required-ci") | .id' <<< "$rulesets" | head -n1)"
if [[ -z "$required_id" ]]; then
  echo "required-ci ruleset not found" >&2
  exit 1
fi

main_payload="$(mktemp)"
dev_payload="$(mktemp)"
trap 'rm -f "$main_payload" "$dev_payload"' EXIT

jq -n '{
  name: "required-ci",
  target: "branch",
  enforcement: "active",
  bypass_actors: [],
  conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}},
  rules: [
    {
      type: "required_status_checks",
      parameters: {
        strict_required_status_checks_policy: false,
        do_not_enforce_on_create: true,
        required_status_checks: [{context: "CI / required"}]
      }
    },
    {
      type: "merge_queue",
      parameters: {
        check_response_timeout_minutes: 15,
        grouping_strategy: "HEADGREEN",
        max_entries_to_build: 2,
        max_entries_to_merge: 1,
        merge_method: "SQUASH",
        min_entries_to_merge: 1,
        min_entries_to_merge_wait_minutes: 0
      }
    }
  ]
}' > "$main_payload"

gh api -H "X-GitHub-Api-Version: $api_version" --method PUT \
  "repos/$repo/rulesets/$required_id" --input "$main_payload" >/dev/null

jq -n '{
  name: "dev-pilot",
  target: "branch",
  enforcement: "active",
  bypass_actors: [],
  conditions: {ref_name: {include: ["refs/heads/dev"], exclude: []}},
  rules: [
    {type: "deletion"},
    {type: "non_fast_forward"},
    {
      type: "pull_request",
      parameters: {
        required_approving_review_count: 1,
        dismiss_stale_reviews_on_push: true,
        require_code_owner_review: false,
        require_last_push_approval: false,
        required_review_thread_resolution: false,
        allowed_merge_methods: ["squash"]
      }
    },
    {
      type: "required_status_checks",
      parameters: {
        strict_required_status_checks_policy: false,
        do_not_enforce_on_create: true,
        required_status_checks: [
          {context: "CI / admission"}
        ]
      }
    }
  ]
}' > "$dev_payload"

dev_id="$(jq -r '.[] | select(.name == "dev-pilot") | .id' <<< "$rulesets" | head -n1)"
if [[ -n "$dev_id" ]]; then
  gh api -H "X-GitHub-Api-Version: $api_version" --method PUT \
    "repos/$repo/rulesets/$dev_id" --input "$dev_payload" >/dev/null
else
  gh api -H "X-GitHub-Api-Version: $api_version" --method POST \
    "repos/$repo/rulesets" --input "$dev_payload" >/dev/null
fi

main_state="$(gh api -H "X-GitHub-Api-Version: $api_version" "repos/$repo/rulesets/$required_id")"
dev_state="$(gh api -H "X-GitHub-Api-Version: $api_version" "repos/$repo/rulesets?includes_parents=false")"

jq -e '
  .rules
  | (map(select(.type == "required_status_checks"))[0].parameters.strict_required_status_checks_policy == false)
    and (any(.[]; .type == "merge_queue"))
' <<< "$main_state" >/dev/null

jq -e '
  any(.[];
    .name == "dev-pilot"
    and ((.rules | map(select(.type == "pull_request")))[0].parameters.required_approving_review_count == 1)
    and any(.rules[]; .type == "required_status_checks"
      and [.parameters.required_status_checks[].context] == ["CI / admission"]))
' <<< "$dev_state" >/dev/null

gh api -H "X-GitHub-Api-Version: $api_version" "repos/$repo/git/ref/heads/dev" >/dev/null
gh api -H "X-GitHub-Api-Version: $api_version" "repos/$repo/git/ref/tags/dev-promoted" >/dev/null

printf 'dev pilot enabled for %s\n' "$repo"
