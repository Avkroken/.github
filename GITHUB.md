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

GitHub App credentials used by Dependabot automation are supplied through organization Actions configuration using `GAMNACKEN_ID` and `GAMNACKEN_PEMKEY`. This public repository contains only credential names and references, never credential values.

## Reusable auto release

`.github/workflows/auto-release.yml` is the reusable GitHub Release implementation for repositories that opt in with a small caller workflow.

The workflow runs only when invoked by a caller and uses the caller repository's normal `GITHUB_TOKEN` with `contents: write`. It does not require organization secrets, a PAT, or a GitHub App.

Stable release tags use `vMAJOR.MINOR.PATCH`. The next version is derived from commits since the latest stable tag: breaking changes, `!`, or `major:` cause a major bump; `feat:` or `minor:` cause a minor bump; `fix:`, `perf:`, or `patch:` cause a patch bump. Other commits do not create a release. GitHub-generated release notes are used for the release body.

Repositories with bespoke release or publishing workflows keep those workflows unless they are explicitly migrated. Callers should pin the reusable workflow to an exact commit SHA.
