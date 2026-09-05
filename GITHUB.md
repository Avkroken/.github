# GITHUB.md

This is the repository governance document for `Avkroken/.github`. Binding AI coding-agent policy is defined only in `Avkroken/.github/AGENTS.md`. This document records repository-specific technical contracts, invariants, validation requirements, and operational context required by that policy; it must not define, supplement, narrow, or override agent policy.

This repository is Avkroken's central source for shared GitHub metadata and repository-policy automation.

## Metadata automation

`.github/workflows/metadata-orchestration.yml` is the reusable entry point for repository metadata automation. It owns event routing, issue-event concurrency, pull-request reconciliation concurrency, the pull-request owner assignee, reconciliation error aggregation, and the dispatch into deterministic issue routing. Repository callers should contain only the repository-local triggers, the minimum explicit token permissions, and a full commit-SHA pin to this reusable workflow. GitHub requires scheduled triggers to be declared in the caller workflow, so each repository keeps only its low-frequency staggered cron value as local trigger configuration; operational metadata values and implementation logic belong here centrally.

`.github/workflows/metadata-routing.yml` is the deterministic issue-routing implementation called by the orchestrator. It assigns `blixten85`, validates classification labels, converts one temporary `classification:<difficulty>:<security>` label into canonical classification labels, and derives `agent:*`, `priority:*`, and `triage:*` labels.

Canonical `difficulty:*` and `security:*` labels take precedence over AI output. The temporary `classification:*` label is transport metadata only and is removed after deterministic conversion. Malformed or conflicting classification metadata routes to `triage:invalid`.

Pull-request owner assignment is reconciled centrally on a low-frequency caller schedule over all open pull requests using a normal Actions token with explicit `issues: write` and `pull-requests: write`. `pull_request_target` label events are used only for the approved metadata-only PR routing path; that path must not check out or execute pull-request code. Scheduled reconciliation remains authoritative for owner assignment. Issue classification/routing remains event-driven through the central reusable workflow.

The metadata-only Agentic Workflow source and generated lock file are kept together and compiled with the repository's pinned stable `github/gh-aw` toolchain. Its permitted behavior is defined only by the `Metadata-only AI triage` section of `AGENTS.md`.

## Reusable workflow pin rollout

Caller repositories pin Avkroken-owned reusable workflows to immutable full commit SHAs. A full SHA identifies a repository commit, so the correct rollout target is the newest commit that contains the relevant workflow family and its required central dependencies, not mechanically the newest commit in `Avkroken/.github`.

`.github/workflows/sync-reusable-workflow-pins.yml` is the deterministic organization rollout mechanism for these Avkroken-owned pins. On a relevant central workflow change it maps the changed workflow family to affected caller references, discovers repositories available to the organization-installed `Gamnacken` App, changes only matching `Avkroken/.github/.github/workflows/<name>@<40-char-sha>` references, and opens ordinary pull requests. It must not push to a caller's default branch, execute caller code, bypass rulesets or reviews, dismiss findings, or merge around a merge queue. It may request native auto-merge; repository protections remain final authority. Rollout auto-merge is always requested with `SQUASH`, matching the organization default-branch merge contract.

`.github/workflows/reconcile-reusable-workflow-pins.yml` is the low-frequency recovery path. Every six hours it discovers the newest relevant commit for each central workflow family and dispatches the normal pin-sync workflow for that exact family/SHA pair. For `metadata-orchestration`, the reconciliation target is the newer of the latest orchestration commit and the latest routing commit because the orchestrator consumes routing by relative reference. This scheduled reconciliation exists so a missed push event, a historical change that predates the rollout workflow, or a transient failed rollout cannot leave caller repositories permanently pinned to an older central implementation.

The sync workflow treats its rollout branches as owned ephemeral state. If the expected rollout branch already has an open pull request, reconciliation reuses that pull request and re-arms squash auto-merge. If the owned rollout branch exists without an open pull request, it is considered stale rollout state and only that branch is deleted before the deterministic rollout is recreated from the caller's current default branch. Unrelated branches are never touched.

Manual dispatch may specify an exact central commit SHA and workflow family for catch-up or recovery. This remains useful for targeted operator recovery and when a later unrelated `.github` commit should not advance an unaffected caller family. Dependabot `github-actions` updates remain enabled as defense in depth for Actions dependencies, but Dependabot is not the authoritative rollout mechanism for Avkroken-owned reusable workflow pins because it does not encode this organization-specific workflow dependency closure.

## Ruleset drift detection

Organization and repository ruleset administration remains an owner operation. `.github/workflows/governance-drift-audit.yml` is therefore detection-only with respect to rulesets: it reads the effective inherited organization `main` ruleset, never writes ruleset configuration, and raises a deterministic repository issue when an owner-side migration is required.

The audit runs after relevant central changes and every six hours. It verifies two assumptions that central automation depends on:

- the effective organization `main` pull-request rule permits exactly the `squash` merge method; and
- the required `OSV-Scanner` workflow pin still resolves to the same workflow file content as `.github/workflows/osv-scanner.yml` on central `main`.

A required-workflow commit SHA is intentionally immutable and does not need to equal the current `.github/main` SHA. Unrelated central commits are not drift. Drift exists when the workflow file content at the ruleset's pinned commit differs from the current central workflow content, or when the merge-method contract changes. When drift is detected, the audit opens or updates the single `governance: required workflow pin drift` issue with the exact observed cause and required owner action, then fails visibly. When the live assumptions are restored, the audit closes that alert. This keeps privileged ruleset mutation out of Actions while preventing silent policy drift.

## CodeRabbit review configuration

CodeRabbit Organization Settings are Avkroken's central review baseline. Repository `.coderabbit.yaml` files use `inheritance: true` so they inherit that baseline and should contain only repository-specific overrides or router-preserving exceptions. No dedicated central CodeRabbit configuration repository is required, and `Avkroken/.github` does not duplicate the Organization Settings baseline.

The organization CodeRabbit configuration should instruct workflow reviews to evaluate Avkroken reusable-workflow SHA bumps against the exact referenced central commit and dependency closure, preserve the thin-caller contract, and avoid recommending that centralized implementation be copied into caller repositories. Router-managed repositories use label-driven CodeRabbit review: automatic review is otherwise disabled, `review:coderabbit` is the positive review trigger, Draft review is allowed, and automatic incremental review after later pushes is disabled. Repository-local `reviews.auto_review` overrides must preserve that contract unless an exception is explicitly documented. `AGENTS.md` remains the binding AI-agent policy; CodeRabbit guidance is review context, not a replacement policy source.

`AGENTS.md` defines one deliberate exception to the otherwise advisory bot-review model: pull requests carrying `review:level:deep` or `review:deep` require a completed substantive CodeRabbit review result that verifiably covers the latest HEAD before readiness or merge automation. A qualifying result may be a submitted GitHub pull-request review or CodeRabbit's completed review/walkthrough artifact or top-level review comment when it explicitly records current-HEAD coverage, such as the reviewed commit SHA or CodeRabbit final-review coverage metadata. A preliminary/status comment, walkthrough placeholder, skipped-review notice, quota response, command acknowledgement, or label acknowledgement does not satisfy that gate. When the label-driven request does not produce a qualifying completed review result, the coding agent or operator must explicitly post `@coderabbitai review`. If CodeRabbit is temporarily unavailable or out of quota, that deep-review pull request waits for CodeRabbit rather than treating another bot as a substitute. Additional paid review capacity is not purchased unless the repository owner explicitly requests it.

The deterministic recovery state for that gate is `review:coderabbit-waiting`. `.github/scripts/deep-coderabbit-gate.sh`, run by the central AI review router schedule, scans open deep-review pull requests and compares CodeRabbit's formal review commit or final-review coverage metadata with the exact current PR HEAD. A current-head completed result clears `review:coderabbit-waiting`; a current-head review already in progress keeps the waiting label without retriggering; missing, skipped, quota-limited, or otherwise non-qualifying results remain waiting and eligible for a later retry. At most one missing deep CodeRabbit request is retriggered per scheduled run by removing and reapplying `review:coderabbit`, so temporary quota or delivery failures recover automatically without unbounded request bursts. This recovery label is separate from `review:pending`, which remains advisory-router state.

The same reconciler deterministically promotes high-blast-radius changes in `Avkroken/.github` to `review:level:deep`, including the binding policy/governance documents, CodeRabbit configuration, central review automation, security/OSV workflow, metadata orchestration/routing, Dependabot auto-merge, release automation, reusable-workflow pin rollout/reconciliation, and governance drift detection. Ordinary documentation such as `README.md` is not promoted merely because it lives in the central repository.

## Advisory AI review routing

`.github/workflows/ai-review-router.yml` is the deterministic organization dispatcher for advisory pull-request review and the scheduler for deep CodeRabbit gate reconciliation. It runs every eight minutes and may also be started manually in dry-run mode. It uses the organization-installed `Gamnacken` App with `issues: write` and `pull-requests: write`; it does not check out or execute code from target pull requests, change their branches, resolve review findings, mark them Ready, enable auto-merge, or merge them.

The deep CodeRabbit reconciliation step runs before ordinary advisory routing. This ordering lets a deep pull request claim `review:coderabbit` as its primary review record before the advisory router evaluates it, preventing a Codex or Copilot acknowledgement from replacing the binding CodeRabbit gate. `review:coderabbit-waiting` remains independent state until exact latest-HEAD CodeRabbit coverage exists.

The advisory router automatically considers human-authored pull requests from `blixten85`. Other human-authored pull requests are included only when explicitly labeled `review:pending` or `review:deep`; bot-authored pull requests are excluded from ordinary advisory routing. The separate deep-gate reconciler may still protect a bot-authored pull request when it is explicitly deep-labeled or when it changes a centrally critical `.github` path. The router creates its review labels lazily in repositories with eligible open pull requests:

- `review:pending` requeues a pull request for a fresh advisory review after a material update and is retained while a routed request is in flight so an interrupted router run can recover on the next schedule;
- `review:coderabbit`, `review:copilot`, and `review:codex` record the selected primary advisory reviewer; `review:coderabbit` also acts as CodeRabbit's positive review trigger;
- `review:coderabbit-waiting` records that a binding deep CodeRabbit gate still lacks qualifying latest-HEAD coverage and is maintained only by the deep-gate reconciler;
- `review:level:normal`, `review:level:elevated`, and `review:level:deep` record the deterministic change-risk level; and
- `review:deep` is a manual override that forces deep handling and activates the binding CodeRabbit gate.

The ordinary advisory level classifier is deterministic and uses only pull-request file paths, file count, and additions/deletions from GitHub metadata. It does not ask an AI model to choose an AI reviewer. Normal is the default. Authentication/login/session, API/server/database paths, dependency manifests/locks, and ordinary workflow changes are elevated; changes of at least 250 lines or 10 files are also elevated. Migrations/schema, security/permissions/authorization, deploy/infrastructure/terraform/ruleset paths, `wrangler.toml`, changes of at least 800 lines or 25 files, and the manual `review:deep` override are deep. The central deep-gate reconciler adds the repository-specific critical-path promotion described above before advisory routing runs.

For ordinary normal/elevated routing, each scheduled run routes only the oldest eligible unrouted or requeued pull request and prefers CodeRabbit, then GitHub Copilot, then Codex. Deep pull requests are first claimed by the binding CodeRabbit reconciler; optional later advisory requeues do not satisfy or replace the latest-HEAD CodeRabbit gate.

For CodeRabbit, selecting the primary reviewer means applying `review:coderabbit`. The automatic deep-gate recovery path re-applies that label when a qualifying latest-HEAD result is missing and does not retrigger while a latest-HEAD review is already in progress. During active coding-agent work, if the label-driven request still does not produce an actual review, the agent or operator posts `@coderabbitai review` explicitly as required by `AGENTS.md`.

The ordinary advisory router waits up to 120 seconds and polls GitHub every 15 seconds for activity from its selected advisory bot. A top-level bot comment, submitted review, or inline review comment created after the request counts as advisory acknowledgement. For ordinary advisory routing an explicit unavailable/quota response advances to the next bot immediately, and no acknowledgement leaves `review:pending` for a later run. These advisory fallback rules do not apply to satisfaction of the deep CodeRabbit gate; deep quota/unavailability remains waiting until a qualifying CodeRabbit result covers the latest HEAD.

Because each scheduled run performs at most one automatic deep CodeRabbit retrigger and the ordinary advisory router processes only one candidate, review request pressure remains bounded by the eight-minute schedule. A review already in progress is not retriggered by deep reconciliation.

The primary-review labels describe the router's selected reviewer, not a merge gate for ordinary pull requests. Repository-native automatic reviews, including organization-level Copilot review, may still produce additional advisory feedback. CodeRabbit auto-review outside the label-driven contract is an explicitly documented repository exception rather than part of the central router. Independent automatic reviews are outside the router's request-rate cap. The only bot-review merge gate defined by `AGENTS.md` is the latest-HEAD CodeRabbit review required for pull requests carrying `review:level:deep` or `review:deep`.

CodeRabbit can apply configured pull-request labels as part of its review/walkthrough, but the documented labeling path is not used as a standalone pre-review classifier. The router therefore keeps `review:level:*` deterministic and does not depend on CodeRabbit to choose its own review level.

## Dependabot merge-queue implementation

`.github/workflows/dependabot-automerge.yml` is the reusable implementation used by repository callers. It uses the organization-installed `Gamnacken` GitHub App to request native Dependabot auto-merge or merge-queue entry according to the central authorization in `AGENTS.md`.

The App-backed reconciliation is invoked from scheduled or manual caller runs. Do not invoke the secret-backed App workflow directly from Dependabot pull-request events: GitHub withholds normal Actions secrets for Dependabot-triggered runs, which prevents this credential model from starting reliably. The recurring reconciliation is the authoritative retry path and still leaves repository rulesets, required checks, reviews and merge queues as the final merge authority.

Dependabot reconciliation always requests `SQUASH`. Before re-arming a pull request, it reads the current native auto-merge request. If an older automation run left `MERGE` or `REBASE` armed, the reconciliation disables only that stale auto-merge request and immediately re-arms the same unchanged PR HEAD with `SQUASH`. It never rebases, updates, or force-pushes the Dependabot branch. If GitHub still refuses queue entry, the workflow reports the live `mergeable` and `mergeStateStatus` values in its warning and leaves the branch untouched for the next reconciliation or owner investigation.

Repository merge-queue rulesets are managed manually through GitHub UI/API by the repository or organization owner. This repository does not use an Actions workflow or GitHub App for repository or organization ruleset reconciliation, and Gamnacken does not require repository or organization Administration solely for ruleset management.

Organization required-workflow and ruleset migrations are owner-operated rather than automated from this repository. The governance drift audit described above is the deterministic detection and escalation path for those privileged migrations.

GitHub App credentials used by organization automation are supplied through organization Actions configuration using the canonical names `GAMNACKEN_CLIENT_ID` and `GAMNACKEN_PRIVATE_KEY`. Reusable workflows resolve the client ID directly from the organization variable, while callers explicitly map only the private-key secret. This public repository contains only credential names and references, never credential values. These canonical names are specific to GitHub Actions; external runtimes do not inherit Actions variables or secrets and must use their own documented runtime bindings.

## Release PR platform

`.github/workflows/release-please.yml` is the reusable release implementation for repositories that explicitly opt in with a small caller workflow.

The organization Actions policy must allow `googleapis/release-please-action@*`. The reusable workflow still pins the action to an exact full commit SHA, so the organization allowlist permits only refs from that repository while each execution remains immutable and auditable.

The release lifecycle is `main -> Release PR -> normal repository checks/reviews/merge queue -> merged Release PR -> draft GitHub Release -> finalized GitHub Release`. The central workflow uses the organization-installed `Gamnacken` GitHub App so Release Please pull requests trigger normal repository workflows. The workflow requests native auto-merge for the exact Release Please pull request it just created or updated using `SQUASH`; repository rulesets and merge queues remain the final merge authority.

Release callers must pin the reusable workflow to an exact commit SHA and explicitly map only the Gamnacken private-key secret. The reusable workflow resolves `GAMNACKEN_CLIENT_ID` from organization Actions variables and pins third-party Actions to full commit SHAs.

Each caller owns two Release Please files at repository root:

- `release-please-config.json`, defining the release strategy and changelog sections;
- `.release-please-manifest.json`, containing the current stable root version.

The central workflow currently supports one root release package per repository. Stable tags use `vMAJOR.MINOR.PATCH`. Release configuration must create draft releases and force tag creation; the central workflow finalizes and publishes the draft after adding organization-standard release metadata.

Release notes are deliberately split by purpose:

- Release Please owns the human-facing code changelog and version bump in the Release PR.
- The central workflow adds a bounded `Dependency updates` section from dependency-bump commits since the previous stable tag, capped at 20 visible entries.
- Repositories may optionally add `.github/release-components.json` for a short first-party `Program versions` table. This table is limited to 12 declared components and supports only declarative release, JSON, or TOML version sources. It must not execute repository commands or enumerate the complete dependency graph.

A component inventory is for first-party programs or shipped artifacts, not libraries. Complete dependency inventories belong in GitHub's dependency graph/SBOM rather than release notes.

Publishing packages, deployment artifacts, app-store builds, container images, Debian packages, or production deployments remains repository-specific and is not performed by the central release workflow unless separately designed and authorized for that repository.
