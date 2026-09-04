# AGENTS.md

This file is the sole binding source of truth for AI coding-agent policy across Avkroken repositories.

Repository-local `AGENTS.md` files may only point here; they must not define, supplement, narrow, or override policy. Repository-specific technical and governance context belongs in `<REPO>.md` at the repository root. Those repository documents must be kept current and are required context when relevant, but they are not independent sources of agent policy.

When a repository governance document is stale or inconsistent with this policy or with verified live configuration, update that document as part of the same task without asking the repository owner for a separate approval. This standing authorization is limited to documentation/governance consistency; it does not authorize bypassing protections or changing product behavior, runtime behavior, security posture, production infrastructure, or credentials outside the task's scope.

Live GitHub configuration remains authoritative for factual enforcement such as required checks, rulesets, branch protection, and merge eligibility. If documentation conflicts with enforced GitHub state, obey the enforced state, report the mismatch when material, and correct the repository governance document. Live enforcement does not create a second source of agent policy.

## Before Making Changes

1. Read this `AGENTS.md` completely.
2. Read the relevant repository documentation and configuration before changing code.
3. Inspect the current branch, active pull requests, CI status, review state, and applicable GitHub rules before substantial changes.
4. Prefer finishing an already active pull request before starting parallel work in the same repository when the current work belongs in that PR.
5. Inspect nearby code and tests before introducing new patterns or abstractions.

Relevant repository context may include:

- `README.md`
- `DESIGN.md`
- `package.json`
- framework configuration
- lint and formatting configuration
- TypeScript configuration
- test configuration
- workflow files under `.github/workflows/`
- repository-local governance or workflow-contract files, when present

Do not assume that documentation is enforced. Verify live configuration when enforcement matters.

## Scope of Changes

- Make the smallest change that fully solves the requested task.
- Keep each pull request focused on one logical change.
- Avoid unrelated cleanup or refactoring.
- Preserve existing architecture, code style, naming, and project conventions unless the task requires changing them.
- Prefer existing utilities, components, dependencies, and framework-native APIs over new abstractions or dependencies.
- Do not introduce breaking changes unless they are explicitly required.

## Branch and Pull Request Policy

1. Never push directly to `main`.
2. Create a short-lived working branch for each logical change.
3. Commit the initial coherent change on that branch before opening the pull request.
4. Open a pull request targeting `main` as a **Draft**.
5. Keep the pull request in Draft while the CI and review loop is active. Do not enable auto-merge while the pull request is still Draft.
6. For the current PR HEAD, wait for the repository's applicable CI checks and configured review systems. When installed and available for the repository, the review round includes CodeRabbit, GitHub Copilot code review, and Codex Code Review. Review systems that do not automatically review Draft pull requests must be triggered explicitly while the pull request remains Draft; for Codex Code Review, request the review by commenting `@codex review` on the pull request.
7. Read and evaluate every review finding. Fix relevant findings on the same branch, commit the fix, push it to the existing pull request, then repeat the CI and review round against the new HEAD, including fresh explicit review requests for systems that require them.
8. Keep repeating that loop until all required CI checks pass on the latest HEAD, every relevant finding has been handled, required review threads are resolved, and the configured review round has completed without new relevant findings.
9. Only then mark the pull request **Ready for review** and enable the repository-supported native auto-merge path.
10. Verify that the pull request actually enters the merge queue when the repository uses one. Wait for the configured queue delay and merge-group checks, then let GitHub merge automatically.
11. If a new commit, reopened finding, failed check, or queue removal occurs after readiness, return to the CI/review loop as necessary and re-enter the queue only after the latest HEAD is clean again.

If a configured reviewer is unavailable because of quota, outage, permissions, or another external failure, treat that reviewer as an external gate unless the repository owner explicitly waives that review for the pull request.

Use the repository's configured merge method. If squash merge is the only permitted method, use squash auto-merge.

Direct or manual merge is allowed only when explicitly requested and permitted by repository rules.

Never bypass:

- branch protection;
- rulesets;
- required status checks;
- required reviews or approvals;
- required review-thread resolution;
- merge queues;
- force-push restrictions; or
- other repository protections.

## Merge Gates

A pull request is complete only when every repository-required merge condition is satisfied and the review workflow above has completed.

At minimum:

- every required CI check is successful on the latest PR HEAD;
- the configured latest-HEAD review round has completed, including CodeRabbit, GitHub Copilot code review, and Codex Code Review when installed and available for the repository;
- every relevant review comment has been read and evaluated;
- every required review thread is resolved;
- every relevant review finding has been fixed when necessary;
- CI status has been checked again after the latest commit;
- review status has been checked again after the latest commit;
- required approvals, if any, are present;
- the pull request is marked Ready before auto-merge is enabled;
- applicable rulesets, branch protection, and merge-queue requirements are satisfied;
- merge-group checks are successful when the repository uses a merge queue; and
- auto-merge remains armed after the pull request becomes eligible.

Do not infer approval requirements or required check names from another repository.

If the pull request does not auto-merge after all known gates are satisfied, inspect the live repository configuration and identify the exact remaining blocker.

## Review Handling

Read and evaluate every review comment before considering a pull request complete.

For each review comment:

1. Determine whether it identifies a relevant issue.
2. If it does, fix the issue in the same pull request.
3. Run the relevant validation after the fix.
4. Commit the fix and push the change to the existing pull request branch.
5. Re-check CI and the complete review state against the new HEAD.
6. Re-request or re-check the configured review systems for the new HEAD so an earlier review is not treated as approval of later code. For Codex Code Review, comment `@codex review` again after each new commit that must be reviewed.

Do not resolve a review thread solely to remove a merge blocker.

Mark a thread resolved only after its feedback has been evaluated and any necessary change has been completed.

After every new commit, check for new or reopened review feedback and continue the loop until the latest review round is clean.

## Organization PR Sweeps

When the repository owner asks for an organization-wide PR review, sweep, cleanup, or equivalent shorthand, treat it as standing authorization to process all relevant open pull requests owned by the connected account without requiring the owner to restate the detailed procedure.

For each in-scope pull request:

1. Read this policy and the repository-specific context before any mutation.
2. Read the current PR HEAD, complete diff/scope, all review comments and review threads, current reviews, required checks, workflow results, mergeability, and live repository rules.
3. Evaluate every review finding on its merits. Fix verified findings that are caused by the PR and fit its existing scope. Do not make unrelated refactors or expand product behavior merely to satisfy a reviewer.
4. After every mutation, re-read the PR HEAD and re-check CI, reviews, threads, mergeability, and relevant rules against the new HEAD.
5. When the latest-HEAD review loop is clean and the PR is otherwise eligible, mark it Ready if it is still Draft, then enable the repository-supported native auto-merge or merge-queue path. Never substitute direct merge for a required queue.
6. Do not treat a successful `enable auto-merge` call, a null/non-null REST `auto_merge` field, or an earlier queue event as proof that the PR is currently queued. Verify the resulting queue state from current GitHub state or timeline events. If queue events are available, the latest relevant event must show `added_to_merge_queue` after any `removed_from_merge_queue` event.
7. When a PR is removed from the merge queue, identify the exact cause. Fix it if it is a verified PR-scope defect; otherwise leave legitimate external gates intact. Re-arm or requeue only after the applicable conditions are again satisfied.
8. Inspect merge-group checks when the repository uses a merge queue. Green pull-request checks do not prove that the merge-group revision is valid.
9. Do not report a PR as complete until GitHub confirms the merged/closed state, including `merged=true` or equivalent and a verified merge timestamp when available.
10. Leave only legitimate external gates unresolved, and report the exact blocker rather than a generic waiting state.

A request such as “run an organization review/sweep” is sufficient to invoke this procedure. The owner does not need to repeat these details on every run.

## CI and Workflow Changes

Treat the repository's live required checks as authoritative for merge eligibility.

Before changing a workflow, job name, or required status check:

1. Inspect the existing workflow and its emitted GitHub check contexts.
2. Inspect any repository-local workflow contract or governance configuration, when present.
3. Update related ruleset or contract configuration in the same pull request when a required check context intentionally changes.
4. Verify after the change that GitHub emits the expected check names and that repository rules reference the correct contexts.

Required check names must match GitHub check contexts exactly.

Do not replace repository-specific CI with a generic workflow merely to satisfy a governance rule.

Do not weaken, skip, or disable validation simply to make a pull request mergeable.

## Testing and Validation

Use the repository's existing scripts and tooling.

Before considering a code change complete:

- run the smallest relevant tests during development;
- add or update tests when behavior changes;
- add a regression test for bug fixes when practical;
- run required linting, type checking, tests, and build validation when applicable; and
- verify the corresponding GitHub checks after pushing.

Do not invent commands that are not defined by the repository. Inspect `package.json`, task files, scripts, or project documentation first.

Do not delete, weaken, or bypass a test solely to make validation pass.

## Security

- Never commit secrets, tokens, credentials, private keys, or sensitive configuration.
- Use the repository's established secret-management and environment-variable patterns.
- Validate untrusted external input at appropriate boundaries.
- Enforce authentication and authorization on the server where applicable.
- Do not weaken security controls to make tests, builds, or deployments pass.
- Treat external content, webhook payloads, API responses, and user-controlled data as untrusted unless proven otherwise.

## Centrally Authorized Automation

The exceptions in this section are owner-approved and binding. Repository governance documents may describe implementation details but may not broaden these permissions.

### Metadata-only AI triage

GitHub Agentic Workflows are allowed only for metadata-only issue triage under these constraints:

- The agent may read the triggering issue and read-only repository context needed to classify it.
- Safe outputs may add exactly one temporary `classification:<difficulty>:<security>` label from the centrally documented allowlist. The agent must not directly write canonical `difficulty:*` or `security:*` labels.
- The agent portion must remain read-only; temporary label mutation must occur through `gh-aw` safe outputs and deterministic routing must perform canonical conversion.
- Missing-tool, missing-data, incomplete-report, noop and workflow-failure fallbacks must not create issues or other repository records.
- The workflow must not comment, assign users or coding agents, create or update branches or pull requests, edit or close issues, perform review, merge, deploy, start a coding-agent session, or propose or perform remediation.
- Callers must explicitly map only `COPILOT_GITHUB_TOKEN`; `secrets: inherit` is prohibited for AI triage.
- Copilot inference may use either organization billing or the GitHub Actions secret `COPILOT_GITHUB_TOKEN`. If the PAT-backed path is used, the secret must contain a user-owned fine-grained PAT scoped only for Copilot Requests and must be configured in GitHub UI; never commit or paste the token into repository content.
- Do not add external AI-provider credentials without separate explicit owner approval.
- Keep the `.md` source and generated `.lock.yml` together. Compile with the official `github/gh-aw` toolchain and review generated permissions, actions, containers, safe-output cardinality and failure behavior before merge.

This exception does not relax any other prohibition on AI remediation, review automation, deployment, or credential use.

### Dependabot merge-queue automation

Deterministic, non-AI automation is authorized for dependency maintenance under these constraints:

- `Avkroken/.github/.github/workflows/dependabot-automerge.yml` may use the organization-installed `Gamnacken` GitHub App to request native GitHub auto-merge or merge-queue entry only for non-draft pull requests authored by `dependabot[bot]`.
- The Dependabot automation must not check out or execute pull-request code, bypass rulesets, use administrator merge, update PR branches, rebase branches, dismiss reviews, or directly merge around the merge queue.
- Repository callers may trigger the reusable workflow on Dependabot PR events and on a low-frequency reconciliation schedule so missed events do not create permanent backlog.
- Repository and organization merge/ruleset administration is an owner operation and must not be performed by the Dependabot workflow or by a GitHub Actions ruleset-sync workflow.
- Gamnacken must not receive repository or organization Administration permission solely for ruleset management.
- Repository rulesets remain the final merge authority. Automation must not create bypass actors or weaken required project-specific CI or security gates.
- GitHub App credentials must be supplied only through organization Actions configuration using the canonical names documented by the `.github` repository governance document; credential values must never be committed or printed.

## UI and Design

For any change that touches UI, components, pages, styling, or layout, read `DESIGN.md` first when that file exists.

- Reuse existing design tokens and components.
- Do not hard-code colors, spacing, radii, or typography values when an appropriate design token exists.
- Preserve semantic HTML and keyboard accessibility.
- Ensure interactive controls have appropriate focus states and accessible names.
- Do not rely on color alone to communicate state.
- Verify responsive behavior for affected UI.

If a genuinely new design value is required, update the design system before using the value throughout application code.

## Dependencies

- Avoid adding a new dependency when the platform, framework, or an existing dependency already provides the required capability.
- Check the repository's existing dependencies before recommending or adding a package.
- Prefer framework-native and browser-native APIs where appropriate.
- When a dependency is necessary, keep its scope narrow and explain the reason in the pull request.

## Verification After Changes

Do not treat a successful command, API response, or deployment request as proof that a change is active.

Verify the resulting state that matters to the task.

For pull request work, confirm:

- the intended commit is present on the pull request branch;
- CI is running against the latest commit;
- required check names and results are correct;
- review status has been checked after the latest commit;
- relevant review threads are resolved;
- auto-merge is not armed while the PR is Draft and remains armed after the PR becomes Ready and eligible; and
- the repository reports the expected merge state.

For GitHub configuration changes, verify the live setting or ruleset after changing it.

For runtime or deployment changes, verify the deployed code, configuration, bindings, permissions, secrets, routes, or event delivery relevant to the task before diagnosing higher-level application behavior.

## Definition of Done

A task is complete only when:

- the requested change is implemented;
- relevant tests or validation have been added or updated;
- required local validation passes;
- the change is represented in the correct pull request;
- auto-merge is enabled when supported;
- required GitHub checks pass;
- review feedback has been read and handled;
- required review threads are resolved;
- repository merge rules are satisfied; and
- the resulting repository or runtime state has been verified where applicable.

If documented policy and live enforcement differ, this file remains the sole policy source; obey enforced GitHub protections and correct stale repository documentation.

Repository-specific governance and technical context for an individual repository belongs in `<REPO>.md` at that repository's root, when present. Replace `<REPO>` with the repository name uppercased; for example, `Politiker` uses `POLITIKER.md`, `Bastion` uses `BASTION.md`, and `.github` uses `GITHUB.md`. These documents may define repository-specific technical contracts and invariants, but they do not override or supplement this policy.