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
fixed_now_epoch=1767227400 # 2026-01-01T00:30:00Z

complete_comment=$'comment\tcoderabbitai[bot]\t-\t-\t2026-01-01T00:29:00Z\t<!-- final_review_risk_coverage:{"sourceCommitId":"f0e1756122a63e70cc35a4df8b1f9c4e093afc71","coveredCommitId":"f0e1756122a63e70cc35a4df8b1f9c4e093afc71","kind":"reviewed"} -->'
fresh_in_progress_comment=$'comment\tcoderabbitai[bot]\t-\t-\t2026-01-01T00:15:00Z\t<!-- This is an auto-generated comment: review in progress by coderabbit.ai --> Reviewing files between 1c37ea3fed36764d931937d7a37284838fe14901 and f0e1756122a63e70cc35a4df8b1f9c4e093afc71.'
stale_in_progress_comment=$'comment\tcoderabbitai[bot]\t-\t-\t2025-12-31T23:59:00Z\t<!-- This is an auto-generated comment: review in progress by coderabbit.ai --> Reviewing files between 1c37ea3fed36764d931937d7a37284838fe14901 and f0e1756122a63e70cc35a4df8b1f9c4e093afc71.'
old_complete_comment=$'comment\tcoderabbitai[bot]\t-\t-\t2026-01-01T00:29:00Z\t<!-- final_review_risk_coverage:{"sourceCommitId":"1c37ea3fed36764d931937d7a37284838fe14901","coveredCommitId":"1c37ea3fed36764d931937d7a37284838fe14901","kind":"reviewed"} -->'
quota_comment=$'comment\tcoderabbitai[bot]\t-\t-\t2026-01-01T00:29:00Z\tReview skipped because quota is unavailable.'
submitted_review=$'review\tcoderabbitai[bot]\tf0e1756122a63e70cc35a4df8b1f9c4e093afc71\tCOMMENTED\t-\tReview completed.'
pending_review=$'review\tcoderabbitai[bot]\tf0e1756122a63e70cc35a4df8b1f9c4e093afc71\tPENDING\t2026-01-01T00:29:00Z\tDraft review.'
stale_submitted_review=$'review\tcoderabbitai[bot]\t1c37ea3fed36764d931937d7a37284838fe14901\tAPPROVED\t-\tOld review.'

assert_eq complete "$(printf '%s\n' "$complete_comment" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "current-head coverage artifact satisfies gate"
assert_eq complete "$(printf '%s\n' "$submitted_review" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "submitted CodeRabbit review on current head satisfies gate"
assert_eq missing "$(printf '%s\n' "$pending_review" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "orphaned pending CodeRabbit review is retry eligible"
assert_eq in_progress "$(printf '%s\n%s\n' "$pending_review" "$fresh_in_progress_comment" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "fresh current-head activity keeps pending review in progress"
assert_eq missing "$(printf '%s\n%s\n' "$pending_review" "$stale_in_progress_comment" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "stale current-head activity makes pending review retry eligible"
assert_eq in_progress "$(printf '%s\n' "$fresh_in_progress_comment" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "fresh current-head in-progress artifact suppresses duplicate trigger"
assert_eq missing "$(printf '%s\n' "$stale_in_progress_comment" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "stale in-progress artifact becomes retry eligible"
assert_eq missing "$(printf '%s\n' "$old_complete_comment" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "old coverage does not satisfy latest-head gate"
assert_eq missing "$(printf '%s\n' "$stale_submitted_review" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "stale submitted review does not satisfy latest-head gate"
assert_eq missing "$(printf '%s\n' "$quota_comment" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "quota response remains retry eligible"
assert_eq complete "$(printf '%s\n%s\n' "$old_complete_comment" "$complete_comment" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "current coverage wins over stale coverage"
assert_eq in_progress "$(printf '%s\n%s\n' "$old_complete_comment" "$fresh_in_progress_comment" | coderabbit_gate_state_from_tsv "$head_sha" "$fixed_now_epoch")" "fresh current in-progress state wins over stale completion"

if ! review_state_is_submitted APPROVED; then
  echo "FAIL: APPROVED must be treated as submitted" >&2
  exit 1
fi
if ! review_state_is_submitted CHANGES_REQUESTED; then
  echo "FAIL: CHANGES_REQUESTED must be treated as submitted" >&2
  exit 1
fi
if ! review_state_is_submitted COMMENTED; then
  echo "FAIL: COMMENTED must be treated as submitted" >&2
  exit 1
fi
if review_state_is_submitted PENDING; then
  echo "FAIL: PENDING must not be treated as submitted" >&2
  exit 1
fi

if ! critical_central_path AGENTS.md; then
  echo "FAIL: AGENTS.md must be central deep-risk scope" >&2
  exit 1
fi
if ! critical_central_path REPO.md; then
  echo "FAIL: REPO.md must be central deep-risk scope" >&2
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
