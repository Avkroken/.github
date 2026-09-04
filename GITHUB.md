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

`.github/workflows/sync-reusable-workflow-pins.yml` is the deterministic organization rollout mechanism for these Avkroken-owned pins. On a relevant central workflow change it maps the changed workflow family to affected caller references, discovers repositories available to the organization-installed `Gamnacken` App, changes only matching `Avkroken/.github/.github/workflows/<name>@<40-char-sha>` references, and opens ordinary pull requests. It must not push to a caller's default branch, execute caller code, bypass rulesets or reviews, dismiss findings, or merge around a merge queue. It may request native auto-merge; repository protections remain final authority.

Manual dispatch may specify an exact central commit SHA and workflow family for catch-up or recovery. This is required when a later unrelated `.github` commit should not advance an unaffected caller family. Dependabot `github-actions` updates remain enabled as defense in depth for Actions dependencies, but Dependabot is not the authoritative rollout mechanism for Avkroken-owned reusable workflow pins because it does not encode this organization-specific workflow dependency closure.

## CodeRabbit review configuration

Repository `.coderabbit.yaml` files use `inheritance: true` so repository-specific review settings can inherit organization defaults. Version-controlled organization-wide CodeRabbit configuration belongs in the dedicated `Avkroken/coderabbit` repository expected by CodeRabbit's central-configuration model; `Avkroken/.github` is not a substitute for that special repository name.

The organization CodeRabbit configuration should instruct workflow reviews to evaluate Avkroken reusable-workflow SHA bumps against the exact referenced central commit and dependency closure, preserve the thin-caller contract, and avoid recommending that centralized implementation be copied into caller repositories. `AGENTS.md` remains the binding AI-agent policy; CodeRabbit guidance is review context, not a replacement policy source.

## Advisory AI review routing

`.github/workflows/ai-review-router.yml` is the deterministic organization dispatcher for advisory pull-request review. It runs every eight minutes and may also be started manually in dry-run mode. It uses the organization-installed `Gamnacken` App with `issues: write` and `pull-requests: write`; it does not check out or execute code from target pull requests, change their branches, resolve review findings, mark them Ready, enable auto-merge, or merge them.

The router automatically considers human-authored pull requests from `blixten85`. Other human-authored pull requests are included only when explicitly labeled `review:pending` or `review:deep`; bot-authored pull requests are excluded. The router creates its review labels lazily in repositories with eligible open pull requests:

- `review:pending` requeues a pull request for a fresh advisory review after a material update;
- `review:coderabbit`, `review:copilot`, and `review:codex` record the selected primary advisory reviewer;
- `review:level:normal`, `review:level:elevated`, and `review:level:deep` record the router's deterministic change-risk level; and
- `review:deep` is a manual override that forces the deep, Codex-first route.

The level classifier is deterministic and uses only pull-request file paths, file count, and additions/deletions from GitHub metadata. It does not ask an AI model to choose an AI reviewer. Normal is the default. Authentication/login/session, API/server/database paths, dependency manifests/locks, and ordinary workflow changes are elevated; changes of at least 250 lines or 10 files are also elevated. Migrations/schema, security/permissions/authorization, deploy/infrastructure/terraform/ruleset paths, `wrangler.toml`, changes of at least 800 lines or 25 files, and the manual `review:deep` override are deep.

Each scheduled run routes only the oldest eligible unrouted or requeued pull request. Normal and elevated pull requests prefer CodeRabbit, then GitHub Copilot, then Codex. Deep pull requests prefer Codex, then CodeRabbit, then GitHub Copilot. Existing preferred reviews may be adopted instead of spending a duplicate request when the pull request has not been explicitly requeued for a fresh review.

After requesting a reviewer, the router waits up to 120 seconds and polls GitHub every 15 seconds for activity from that bot. A top-level bot comment, submitted review, or inline review comment created after the request counts as acknowledgement; CodeRabbit's preliminary/status comment therefore stops fallback while the full review continues asynchronously. An explicit unavailable/quota response advances to the next bot immediately. If no bot activity appears within two minutes, the router tries the next bot in the route. If no bot acknowledges after the full route, the pull request is left or marked `review:pending` for a later scheduled run.

Because only one pull request is selected per scheduled run and normal/elevated routes can issue at most one new CodeRabbit request in that run, router-generated CodeRabbit requests remain capped at eight per clock hour by the eight-minute schedule. Fallback requests do not make any bot approval a merge requirement.

The primary-review labels describe the router's selected reviewer, not a merge gate. Repository-native automatic reviews, including organization-level Copilot review and any repository-level CodeRabbit auto-review that remains enabled, may still produce additional advisory feedback. Those independent automatic reviews are outside the router's request-rate cap and remain non-blocking under `AGENTS.md` unless a live repository rule explicitly requires something else.

## Dependabot merge-queue implementation

`.github/workflows/dependabot-automerge.yml` is the reusable implementation used by repository callers. It uses the organization-installed `Gamnacken` GitHub App to request native Dependabot auto-merge or merge-queue entry according to the central authorization in `AGENTS.md`.

The App-backed reconciliation is invoked from scheduled or manual caller runs. Do not invoke the secret-backed App workflow directly from Dependabot pull-request events: GitHub withholds normal Actions secrets for Dependabot-triggered runs, which prevents this credential model from starting reliably. The recurring reconciliation is the authoritative retry path and still leaves repository rulesets, required checks, reviews and merge queues as the final merge authority.

Repository merge-queue rulesets are managed manually through GitHub UI/API by the repository or organization owner. This repository does not use an Actions workflow or GitHub App for repository or organization ruleset reconciliation, and Gamnacken does not require repository or organization Administration solely for ruleset management.

Organization required-workflow and ruleset migrations are owner-operated rather than automated from this repository.

GitHub App credentials used by organization automation are supplied through organization Actions configuration using the canonical names `GAMNACKEN_CLIENT_ID` and `GAMNACKEN_PRIVATE_KEY`. Reusable workflows resolve the client ID directly from the organization variable, while callers explicitly map only the private-key secret. This public repository contains only credential names and references, never credential values. These canonical names are specific to GitHub Actions; external runtimes do not inherit Actions variables or secrets and must use their own documented runtime bindings.

## Release PR platform

`.github/workflows/release-please.yml` is the reusable release implementation for repositories that explicitly opt in with a small caller workflow.

The organization Actions policy must allow `googleapis/release-please-action@*`. The reusable workflow still pins the action to an exact full commit SHA, so the organization allowlist permits only refs from that repository while each execution remains immutable and auditable.

The release lifecycle is `main -> Release PR -> normal repository checks/reviews/merge queue -> merged Release PR -> draft GitHub Release -> finalized GitHub Release`. The central workflow uses the organization-installed `Gamnacken` GitHub App so Release Please pull requests trigger normal repository workflows. The workflow may request native auto-merge for the exact Release Please pull request it just created or updated, but repository rulesets and merge queues remain the final merge authority.

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
