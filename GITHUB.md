# GITHUB.md

This is the repository governance document for `Avkroken/.github`. Binding AI coding-agent policy is defined only in `Avkroken/.github/AGENTS.md`. This document records repository-specific technical contracts, invariants, validation requirements, and operational context required by that policy; it must not define, supplement, narrow, or override agent policy.

This repository is Avkroken's central source for shared GitHub metadata and repository-policy automation.

## Metadata automation

`.github/workflows/metadata-routing.yml` is deterministic metadata automation. It assigns `blixten85`, validates classification labels, converts one temporary `classification:<difficulty>:<security>` label into canonical classification labels, and derives `agent:*`, `priority:*`, and `triage:*` labels.

Canonical `difficulty:*` and `security:*` labels take precedence over AI output. The temporary `classification:*` label is transport metadata only and is removed after deterministic conversion. Malformed or conflicting classification metadata routes to `triage:invalid`.

Pull-request metadata callers use ordinary `pull_request` events only for same-repository, non-Dependabot pull requests where the event token can write safely. Fork, Dependabot, and missed pull-request events are covered by low-frequency scheduled reconciliation over open pull requests. Do not use `pull_request_target` for this caller path: current GitHub execution rejects these workflows at startup before any job runs.

The metadata-only Agentic Workflow source and generated lock file are kept together and compiled with the repository's pinned stable `github/gh-aw` toolchain. Its permitted behavior is defined only by the `Metadata-only AI triage` section of `AGENTS.md`.

## Dependabot merge-queue implementation

`.github/workflows/dependabot-automerge.yml` is the reusable implementation used by repository callers. It uses the organization-installed `Gamnacken` GitHub App to request native Dependabot auto-merge or merge-queue entry according to the central authorization in `AGENTS.md`.

The App-backed reconciliation is invoked from scheduled or manual caller runs. Do not invoke the secret-backed App workflow directly from Dependabot pull-request events: GitHub withholds normal Actions secrets for Dependabot-triggered runs, which prevents this credential model from starting reliably. The recurring reconciliation is the authoritative retry path and still leaves repository rulesets, required checks, reviews and merge queues as the final merge authority.

Repository merge-queue rulesets are managed manually through GitHub UI/API by the repository or organization owner. This repository does not use an Actions workflow or GitHub App for repository or organization ruleset reconciliation, and Gamnacken does not require repository or organization Administration solely for ruleset management.

Organization required-workflow and ruleset migrations are owner-operated rather than automated from this repository.

GitHub App credentials used by Dependabot automation are supplied through organization Actions configuration using `GAMNACKEN_ID` and `GAMNACKEN_PEMKEY`. This public repository contains only credential names and references, never credential values.
