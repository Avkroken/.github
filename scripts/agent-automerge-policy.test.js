const fs = require("node:fs");
const assert = require("node:assert/strict");

const policy = fs.readFileSync(".github/workflows/agent-automerge-policy.yml", "utf8");
const caller = fs.readFileSync(".github/workflows/agent-automerge.yml", "utf8");

assert.match(policy, /workflow_call:/);
assert.match(policy, /user\.login == 'gamnacken\[bot\]'/);
assert.match(policy, /head\.repo\.full_name == github\.repository/);
assert.match(policy, /base\.ref == github\.event\.repository\.default_branch/);
assert.match(policy, /startsWith\(github\.event\.pull_request\.head\.ref, 'codex\/'\)/);
assert.match(policy, /pull_request\.draft == false/);
assert.match(policy, /gh pr merge --auto --merge/);
assert.doesNotMatch(policy, /actions\/checkout/);
assert.doesNotMatch(policy, /pull_request_target/);

assert.match(caller, /pull_request:/);
assert.match(caller, /types: \[opened, reopened, synchronize, ready_for_review\]/);
assert.match(caller, /permissions:\s*\{\}/);
assert.match(caller, /contents: write/);
assert.match(caller, /pull-requests: write/);
assert.match(caller, /uses: \.\/\.github\/workflows\/agent-automerge-policy\.yml/);
assert.doesNotMatch(caller, /pull_request_target/);

console.log("agent auto-merge policy verified");
