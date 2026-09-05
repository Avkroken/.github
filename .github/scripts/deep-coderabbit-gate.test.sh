#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OWNER=Avkroken
# shellcheck source=deep-coderabbit-gate.sh
source "$SCRIPT_DIR/deep-coderabbit-gate.sh"

assert_eq() {
  local expected="$1" actual="$2" message="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $message: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

head_sha='f0e1756122a63e70cc35a4df8b1f9c4e093afc71'
old_sha='1c37ea3fed36764d931937d7a37284838fe14901'

complete_comment=$'comment\tcoderabbitai[bot]\t\t<!-- final_review_risk_coverage:{"sourceCommitId":"f0e1756122a63e70cc35a4df8b1f9c4e093afc71","coveredCommitId":"f0e1756122a63e70cc35a4df8b1f9c4e093afc71","kind":"reviewed"} -->'
in_progress_comment=$'comment\tcoderabbitai[bot]\t\t<!-- This is an auto-generated comment: review in progress by coderabbit.ai --> Reviewing files between 1c37ea3fed36764d931937d7a37284838fe14901 and f0e1756122a63e70cc35a4df8b1f9c4e093afc71.'
old_complete_comment=$'comment\tcoderabbitai[bot]\t\t<!-- final_review_risk_coverage:{"sourceCommitId":"1c37ea3fed36764d931937d7a37284838fe14901","coveredCommitId":"1c37ea3fed36764d931937d7a37284838fe14901","kind":"reviewed"} -->'
quota_comment=$'comment\tcoderabbitai[bot]\t\tReview skipped because quota is unavailable.'
formal_review=$'review\tcoderabbitai[bot]\tf0e1756122a63e70cc35a4df8b1f9c4e093afc71\tReview completed.'

assert_eq complete "$(printf '%s\n' "$complete_comment" | coderabbit_gate_state_from_tsv "$head_sha")" "current-head coverage artifact satisfies gate"
assert_eq complete "$(printf '%s\n' "$formal_review" | coderabbit_gate_state_from_tsv "$head_sha")" "formal CodeRabbit review on current head satisfies gate"
assert_eq in_progress "$(printf '%s\n' "$in_progress_comment" | coderabbit_gate_state_from_tsv "$head_sha")" "current-head in-progress review suppresses duplicate trigger"
assert_eq missing "$(printf '%s\n' "$old_complete_comment" | coderabbit_gate_state_from_tsv "$head_sha")" "old coverage does not satisfy latest-head gate"
assert_eq missing "$(printf '%s\n' "$quota_comment" | coderabbit_gate_state_from_tsv "$head_sha")" "quota response remains retry eligible"
assert_eq complete "$(printf '%s\n%s\n' "$old_complete_comment" "$complete_comment" | coderabbit_gate_state_from_tsv "$head_sha")" "current coverage wins over stale coverage"
assert_eq in_progress "$(printf '%s\n%s\n' "$old_complete_comment" "$in_progress_comment" | coderabbit_gate_state_from_tsv "$head_sha")" "current in-progress state wins over stale completion"

if ! critical_central_path AGENTS.md; then
  echo "FAIL: AGENTS.md must be central deep-risk scope" >&2
  exit 1
fi
if ! critical_central_path .github/workflows/dependabot-automerge.yml; then
  echo "FAIL: central Dependabot workflow must be deep-risk scope" >&2
  exit 1
fi
if critical_central_path README.md; then
  echo "FAIL: ordinary central documentation must not be forced deep" >&2
  exit 1
fi

# Ensure the test fixture really uses a stale SHA distinct from current HEAD.
if [[ "$old_sha" == "$head_sha" ]]; then
  echo "FAIL: stale/current test SHAs unexpectedly match" >&2
  exit 1
fi

echo "Deep CodeRabbit gate tests passed"
