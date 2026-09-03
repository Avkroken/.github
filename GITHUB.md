# GITHUB.md

This is the repository governance document for `Avkroken/.github`. Binding AI coding-agent policy is defined only in `Avkroken/.github/AGENTS.md`. This document records repository-specific technical contracts, invariants, validation requirements, and operational context required by that policy; it must not define, supplement, narrow, or override agent policy.

This repository is Avkroken's central source for shared GitHub metadata and repository-policy automation.

## Metadata automation

`.github/workflows/metadata-routing.yml` is deterministic metadata automation. It assigns `blixten85`, validates classification labels, converts one temporary `classification:<difficulty>:<security>` label into canonical classification labels, and derives `agent:*`, `priority:*`, and `triage:*` labels.

Canonical `difficulty:*` and `security:*` labels take precedence over AI output. The temporary `classification:*` label is transport metadata only and is removed after deterministic conversion. Malformed or conflicting classification metadata routes to `triage:invalid`.

Pull-request owner metadata is reconciled on a low-frequency schedule over all open pull requests using a normal Actions token with explicit `issues: write` and `pull-requests: write`. Do not use `pull_request_target` or ordinary `pull_request` for this write path: the former is rejected at workflow startup by current GitHub execution policy, while the latter cannot reliably mutate pull-request assignees. Issue classification/routing remains event-driven through the central reusable workflow.

The metadata-only Agentic Workflow source and generated lock file are kept together and compiled with the repository's pinned stable `github/gh-aw` toolchain. Its permitted behavior is defined only by the `Metadata-only AI triage` section of `AGENTS.md`.

## Dependabot merge-queue implementation

`.github/workflows/dependabot-automerge.yml` is the reusable implementation used by repository callers. It uses the organization-installed `Gamnacken` GitHub App to request native Dependabot auto-merge or merge-queue entry according to the central authorization in `AGENTS.md`.

The App-backed reconciliation is invoked from scheduled or manual caller runs. Do not invoke the secret-backed App workflow directly from Dependabot pull-request events: GitHub withholds normal Actions secrets for Dependabot-triggered runs, which prevents this credential model from starting reliably. The recurring reconciliation is the authoritative retry path and still leaves repository rulesets, required checks, reviews and merge queues as the final merge authority.

Repository merge-queue rulesets are managed manually through GitHub UI/API by the repository or organization owner. This repository does not use an Actions workflow or GitHub App for repository or organization ruleset reconciliation, and Gamnacken does not require repository or organization Administration solely for ruleset management.

Organization required-workflow and ruleset migrations are owner-operated rather than automated from this repository.

GitHub App credentials used by organization automation are supplied through organization Actions configuration. Current callers use `GAMNACKEN_CLIENT_ID` and `GAMNACKEN_PRIVATE_KEY`. This public repository contains only credential names and references, never credential values.

## Release PR platform

`.github/workflows/release-please.yml` is the reusable release implementation for repositories that explicitly opt in with a small caller workflow.

The release lifecycle is `main -> Release PR -> normal repository checks/reviews/merge queue -> merged Release PR -> draft GitHub Release -> finalized GitHub Release`. The central workflow uses the organization-installed `Gamnacken` GitHub App so Release Please pull requests trigger normal repository workflows. The workflow may request native auto-merge for the exact Release Please pull request it just created or updated, but repository rulesets and merge queues remain the final merge authority.

Release callers must pin the reusable workflow to an exact commit SHA and explicitly map only the Gamnacken client ID and private key. The reusable workflow itself pins third-party Actions to full commit SHAs.

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
