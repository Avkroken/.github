const fs = require("node:fs");
const assert = require("node:assert/strict");

const policy = fs.readFileSync(".github/workflows/agent-automerge-policy.yml", "utf8");
const caller = fs.readFileSync(".github/workflows/agent-automerge.yml", "utf8");
const signal = fs.readFileSync(".github/workflows/agent-lifecycle-signal.yml", "utf8");

assert.match(policy, /workflow_call:/);
assert.match(policy, /gamnacken\[bot\]/);
assert.match(policy, /head_repo.*REPOSITORY/);
assert.match(policy, /base_ref.*default_branch/);
assert.match(policy, /head_ref.*codex\/\*/);
assert.match(policy, /reviewThreads\(first:100\)/);
assert.match(policy, /CHANGES_REQUESTED/);
assert.match(policy, /update-branch/);
assert.match(policy, /expected_head_sha/);
assert.match(policy, /mergeable_state.*dirty/);

assert.match(policy, /expected_external_checks/);
for (const name of [
  "Workers Builds: avkroken",
  "Workers Builds: dumpen",
  "Workers Builds: jobb",
  "Workers Builds: skvallerbyttan",
  "Workers Builds: klarsprak",
  "Workers Builds: politiker",
  "Workers Builds: produkter",
  "Workers Builds: produkter-bearbetare",
  "Workers Builds: produkter-motor",
]) {
  assert.ok(policy.includes(name), name);
}
assert.match(policy, /check-runs\?per_page=100/);
assert.match(policy, /max_by\(\.id\)/);
assert.match(policy, /external_check_gate/);
assert.match(policy, /status.*completed/);
assert.match(policy, /conclusion.*success/);
assert.match(policy, /gh pr merge --disable-auto/);
assert.match(policy, /gh pr merge --auto/);
assert.doesNotMatch(policy, /actions\/checkout/);
assert.doesNotMatch(policy, /pull_request_target/);

assert.match(caller, /pull_request:/);
assert.doesNotMatch(caller, /pull_request_review:/);
assert.doesNotMatch(caller, /pull_request_review_comment:/);
assert.match(caller, /workflow_run:/);
assert.match(caller, /workflows: \["Agent lifecycle signal"\]/);
assert.match(signal, /pull_request_review:/);
assert.match(signal, /pull_request_review_comment:/);
assert.match(signal, /permissions:\s*\{\}/);
assert.match(caller, /check_run:/);
assert.match(caller, /types: \[completed\]/);
assert.match(caller, /push:/);
assert.match(caller, /schedule:/);
assert.match(caller, /workflow_dispatch:/);
assert.match(caller, /permissions:\s*\{\}/);
assert.match(caller, /checks: read/);
assert.match(caller, /contents: write/);
assert.match(caller, /pull-requests: write/);
assert.doesNotMatch(caller, /checks: write|statuses: write|actions: write/);
assert.match(caller, /uses: \.\/\.github\/workflows\/agent-automerge-policy\.yml/);
assert.doesNotMatch(caller, /pull_request_target/);

console.log("agent PR lifecycle external-check gate verified");
