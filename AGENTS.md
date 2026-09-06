# AGENTS.md

This file defines the shared AI coding-agent policy and default working model for Avkroken repositories. It deliberately stays general; repository-specific requirements belong in each repository's `REPO.md`.

Repository-local `AGENTS.md` files may only point here. For any repository that has a root `REPO.md`, agents must read this file and that repository's `REPO.md` together before making changes.

The governance hierarchy is based on scope and specificity:

- live GitHub configuration is authoritative for factual enforcement such as required checks, rulesets, branch protection, merge eligibility, and merge queues;
- the repository's root `REPO.md` is authoritative for repository-specific technical contracts, invariants, validation requirements, constraints, and explicit operating instructions; and
- this `AGENTS.md` defines organization-wide defaults and shared requirements that apply where the repository-specific document does not specialize them.

A repository-specific `REPO.md` may add, narrow, or explicitly vary shared defaults when repository-specific conditions require a different procedure. That is the intended mechanism for expressing local behavior that does not belong in this central file. A repository document must never claim permission to bypass live GitHub protections or ignore required checks, reviews, rulesets, merge queues, or other enforced protections.

When central and repository-specific documentation appear inconsistent, first determine whether they address the same scope. For a repository-specific matter, follow the repository-specific instruction. For a shared matter that is not specialized locally, follow this file. If either document is stale or inconsistent with verified live configuration, update the stale governance documentation as part of the same task without asking the repository owner for separate approval. This standing authorization is limited to documentation/governance consistency; it does not authorize bypassing protections or changing product behavior, runtime behavior, security posture, production infrastructure, or credentials outside the task's scope.

## Before Making Changes

1. Read this `AGENTS.md` completely.
2. Read the relevant repository documentation and configuration before changing code, including the root `REPO.md` when present.
3. Inspect the current branch, active pull requests, CI status, review state, and applicable GitHub rules before substantial changes.
4. Prefer finishing an already active pull request before starting parallel work in the same repository when the current work belongs in that PR.
5. Inspect nearby code and tests before introducing new patterns or abstractions.

Relevant repository context may include:

- `REPO.md`
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
5. Keep the pull request in Draft while required CI and any useful review work is active. Do not enable auto-merge while the pull request is still Draft.
6. For the current PR HEAD, wait for the repository's applicable required CI checks. Bot reviews are advisory and best-effort, not merge requirements. When installed, CodeRabbit, GitHub Copilot code review, and Codex Code Review may be used when useful and available, but their completion, approval, availability, quota, or response is never required to mark a pull request Ready or to merge it. Do not consume paid review credits merely to satisfy this workflow.
7. Read and evaluate every review finding that is actually received. Fix relevant findings on the same branch, commit the fix, push it to the existing pull request, then repeat the required CI checks against the new HEAD. Re-request a bot review only when it is useful and available; a fresh bot review after every commit is not required.
8. Keep repeating the required CI and fix loop until all required CI checks pass on the latest HEAD, every relevant received finding has been handled, and required review threads are resolved. Do not wait for an advisory bot review to start, finish, approve, or regain quota.
9. Only then mark the pull request **Ready for review** and enable the repository-supported native auto-merge path.
10. Verify that the pull request actually enters the merge queue when the repository uses one. Wait for the configured queue delay and merge-group checks, then let GitHub merge automatically.
11. If a new commit, reopened finding, failed check, or queue removal occurs after readiness, return to the required CI/fix loop as necessary and re-enter the queue only after the latest HEAD is clean again.

Quota exhaustion, outage, permissions, non-response, or other unavailability from an advisory bot reviewer is not an external gate and must not block Ready status, auto-merge, merge-queue entry, or completion. Do not purchase additional bot-review capacity solely to satisfy this workflow unless the repository owner explicitly requests it.

The centrally authorized Dependabot automation defined below is an explicit exception to this Draft/review/Ready sequencing. It may request native auto-merge for eligible non-draft Dependabot pull requests before the ordinary review loop completes, but repository rulesets, required checks, and merge-queue gates remain authoritative and must not be bypassed.

Use the repository's configured merge method. If squash merge is the only permitted method, use squash auto-merge.

Direct or manual merge is allowed only when explicitly requested and permitted by repository rules. A repository-specific `REPO.md` may provide that explicit standing request for documented repository-specific situations.

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

A pull request is complete only when every repository-required merge condition is satisfied and all relevant feedback actually received has been handled.

At minimum:

- every required CI check is successful on the latest PR HEAD;
- advisory bot-review completion, approval, availability, quota, and latest-HEAD re-review are not merge gates unless a repository-specific instruction or live enforced rule explicitly makes one required;
- every relevant review comment that was received has been read and evaluated;
- every required review thread is resolved;
- every relevant review finding that was received has been fixed when necessary;
- CI status has been checked again after the latest commit;
- required review state has been checked again after the latest commit;
- required approvals, if any, are present;
- the pull request is marked Ready before auto-merge is enabled;
- applicable rulesets, branch protection, and merge-queue requirements are satisfied;
- merge-group checks are successful when the repository uses a merge queue; and
- auto-merge remains armed after the pull request becomes eligible when that is the repository's applicable path.

Do not infer approval requirements or required check names from another repository.

If the pull request does not auto-merge after all known gates are satisfied, inspect the live repository configuration and the repository-specific `REPO.md`, then follow the applicable repository-specific completion path. Do not invent a blocker that the repository does not actually have.

## Review Handling

Read and evaluate every review comment that is actually received before considering a pull request complete.

For each review comment:

1. Determine whether it identifies a relevant issue.
2. If it does, fix the issue in the same pull request.
3. Run the relevant validation after the fix.
4. Commit the fix and push the change to the existing pull request branch.
5. Re-check required CI and the required review state against the new HEAD.
6. Optionally re-request advisory bot reviewers when useful and available. A fresh CodeRabbit, GitHub Copilot, or Codex Code Review round is not required for merge unless repository-specific governance or live enforcement explicitly requires it.

Do not resolve a review thread solely to remove a merge blocker.

Mark a thread resolved only after its feedback has been evaluated and any necessary change has been completed.

After every new commit, check for new or reopened feedback that already exists or arrives, but do not wait for or force a new advisory bot review before continuing once the repository's actual required gates are satisfied.

## Organization PR Sweeps

When the repository owner asks for an organization-wide PR review, sweep, cleanup, or equivalent shorthand, treat it as standing authorization to process all relevant open pull requests owned by the connected account without requiring the owner to restate the detailed procedure.

For each in-scope pull request:

1. Read this policy and the repository-specific context before any mutation.
2. Read the current PR HEAD, complete diff/scope, all review comments and review threads, current reviews, required checks, workflow results, mergeability, and live repository rules.
3. Evaluate every review finding on its merits. Fix verified findings that are caused by the PR and fit its existing scope. Do not make unrelated refactors or expand product behavior merely to satisfy a reviewer.
4. After every mutation, re-read the PR HEAD and re-check required CI, received reviews, threads, mergeability, and relevant rules against the new HEAD.
5. When required CI is green, relevant received feedback has been handled, required review conditions are satisfied, and the PR is otherwise eligible, mark it Ready if it is still Draft, then follow the repository-supported completion path defined by live rules and repository-specific governance. Never substitute direct merge for a required queue, and never wait solely for an advisory bot reviewer unless that review is explicitly required for the repository.
6. Do not treat a successful `enable auto-merge` call, a null/non-null REST `auto_merge` field, or an earlier queue event as proof that the PR is currently queued. Verify the resulting queue state from current GitHub state or timeline events. If queue events are available, the latest relevant event must show `added_to_merge_queue` after any `removed_from_merge_queue` event.
7. When a PR is removed from the merge queue, identify the exact cause. Fix it if it is a verified PR-scope defect; otherwise leave legitimate external gates intact. Re-arm or requeue only after the applicable conditions are again satisfied.
8. Inspect merge-group checks when the repository uses a merge queue. Green pull-request checks do not prove that the merge-group revision is valid.
9. Do not report a PR as complete until GitHub confirms the merged/closed state, including `merged=true` or equivalent and a verified merge timestamp when available.
10. Leave only legitimate repository or external gates unresolved, and report the exact blocker rather than a generic waiting state. Advisory bot-review quota, outage, or non-response is not such a gate unless repository-specific governance or live enforcement explicitly makes it one.

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

The exceptions in this section are organization-wide authorizations and constraints for the named central automation. Repository-specific governance may document additional local automation behavior, but it must not misrepresent or bypass the constraints of these central workflows.

### Metadata-only AI triage

GitHub Agentic Workflows are allowed only for metadata-only issue triage under these constraints:

- The agent may read the triggering issue and read-only repository context needed to classify it.
- Safe outputs may add exactly one temporary `classification:<difficulty>:<security>` label from the centrally documented allowlist. The agent must not directly write canonical `difficulty:*` or `security:*` labels.
- The agent portion must remain read-only; temporary label mutation must occur through `gh-aw` safe outputs and deterministic routing must perform canonical conversion.
- Missing-tool, missing-data, incomplete-report, noop and workflow-failure fallbacks must not create issues or other repository records.
- The workflow must not comment, assign users or coding agents, create or update branches or pull requests, edit or close issues, perform review, merge, deploy, start a coding-agent session, or propose or perform remediation.
- Callers must grant `copilot-requests: write` to the reusable triage job and must not provide a PAT or Actions secret through `COPILOT_GITHUB_TOKEN`; `secrets: inherit` is prohibited for AI triage.
- Copilot inference for this central triage path uses organization Copilot billing through the caller's `GITHUB_TOKEN` with `copilot-requests: write`. The generated reusable workflow may expose that token internally as `COPILOT_GITHUB_TOKEN` for Copilot tool compatibility; callers do not supply a separate PAT or Copilot token secret.
- Generic cross-repository fallback text in a generated lock file that tells callers to configure a `COPILOT_GITHUB_TOKEN` secret is stale for this central workflow and does not override the caller contract above. Do not hand-edit the generated lock solely to suppress that message; correct it through the official `gh-aw` source/toolchain path.
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
- received review feedback and required review state have been checked after the latest commit;
- required review threads are resolved;
- the repository-specific completion path has been followed; and
- the repository reports the expected merge state.

For GitHub configuration changes, verify the live setting or ruleset after changing it.

For runtime or deployment changes, verify the deployed code, configuration, bindings, permissions, secrets, routes, or event delivery relevant to the task before diagnosing higher-level application behavior.

## Definition of Done

A task is complete only when:

- the requested change is implemented;
- relevant tests or validation have been added or updated;
- required local validation passes;
- the change is represented in the correct pull request;
- the repository-specific merge/completion path has been followed;
- required GitHub checks pass;
- review feedback that was actually received has been read and handled;
- required review threads are resolved;
- repository merge rules are satisfied; and
- the resulting repository or runtime state has been verified where applicable.

If documented governance and live enforcement differ, obey enforced GitHub protections and correct stale documentation. For repository-specific matters, the repository's `REPO.md` is the applicable governance source; for shared matters not specialized there, this file applies.

Repository-specific governance and technical context for an individual repository belongs in `REPO.md` at that repository's root, when present. The filename is always exactly `REPO.md`, regardless of repository name. These documents are binding repository governance and may define repository-specific requirements, constraints, technical contracts, validation rules, and explicit operating instructions, including specializations of shared defaults where local conditions require them. Read them together with this file; do not use the central policy's generality as a reason to ignore a more specific repository instruction.