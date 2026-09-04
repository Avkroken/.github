#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OWNER=Avkroken
# shellcheck source=ai-review-router.sh
source "$SCRIPT_DIR/ai-review-router.sh"

assert_eq() {
  local expected="$1" actual="$2" message="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $message: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_eq normal "$(classify_change_tsv $'README.md\t20\t5\napp/public/site.css\t12\t3')" "docs and CSS stay normal"
assert_eq elevated "$(classify_change_tsv $'app/auth/login.ts\t30\t5')" "auth changes are elevated"
assert_eq elevated "$(classify_change_tsv $'.github/workflows/ci.yml\t20\t4')" "workflow changes are elevated"
assert_eq deep "$(classify_change_tsv $'app/migrations/0007.sql\t20\t0')" "migrations are deep"
assert_eq deep "$(classify_change_tsv $'app/security/permissions.ts\t15\t2')" "security permissions are deep"
assert_eq elevated "$(classify_change_tsv $'src/a.ts\t250\t0')" "medium diffs are elevated"
assert_eq deep "$(classify_change_tsv $'src/a.ts\t800\t0')" "large diffs are deep"

since='2026-09-04T20:00:00Z'
assert_eq acknowledged "$(printf '%s\n' $'2026-09-04T20:00:05Z\tcoderabbitai[bot]\tReview is in progress' | activity_state_from_tsv coderabbit "$since")" "CodeRabbit preliminary comment acknowledges the request"
assert_eq unavailable "$(printf '%s\n' $'2026-09-04T20:00:05Z\tcoderabbitai[bot]\tReview skipped because quota is unavailable' | activity_state_from_tsv coderabbit "$since")" "CodeRabbit explicit unavailability falls back"
assert_eq unavailable "$(printf '%s\n' $'2026-09-04T20:00:05Z\tchatgpt-codex-connector[bot]\tYou have reached your Codex usage limits for code reviews.' | activity_state_from_tsv codex "$since")" "Codex quota response falls back"
assert_eq none "$(printf '%s\n' $'2026-09-04T19:59:59Z\tcoderabbitai[bot]\tOld review' | activity_state_from_tsv coderabbit "$since")" "old bot activity does not satisfy a new request"
assert_eq none "$(printf '%s\n' $'2026-09-04T20:00:05Z\tgamnacken[bot]\treview:coderabbit' | activity_state_from_tsv coderabbit "$since")" "router label mutation is not bot acknowledgement"

assert_eq 'coderabbit copilot codex' "$(bot_chain_for_level normal)" "normal fallback order"
assert_eq 'coderabbit copilot codex' "$(bot_chain_for_level elevated)" "elevated fallback order"
assert_eq 'codex coderabbit copilot' "$(bot_chain_for_level deep)" "deep fallback order"

if grep -Fq '@coderabbitai review' "$SCRIPT_DIR/ai-review-router.sh"; then
  echo "FAIL: CodeRabbit must be triggered by review:coderabbit, not a command comment" >&2
  exit 1
fi

if ! grep -Fq 'selected="review:$bot"' "$SCRIPT_DIR/ai-review-router.sh"; then
  echo "FAIL: router must select the primary review label before dispatch" >&2
  exit 1
fi

echo "AI review router tests passed"