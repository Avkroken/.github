# REPO.md

`Avkroken/.github` is the central source for shared GitHub automation and repository metadata. Shared agent behavior lives in `AGENTS.md`; this file contains only repository-specific contracts.

## Shared automation

- `.github/workflows/metadata-orchestration.yml` and `metadata-routing.yml` own deterministic metadata routing. Repository callers should contain only local triggers, minimum permissions and immutable full-SHA references.
- `issue-classification.md` and its generated `.lock.yml` are one unit. The AI part is metadata-only and remains inside the limits in `AGENTS.md`.
- `sync-reusable-workflow-pins.yml` and `reconcile-reusable-workflow-pins.yml` update Avkroken-owned reusable-workflow pins through ordinary pull requests. They must not push to caller default branches, execute caller PR code or bypass repository protections.
- `dependabot-automerge.yml` may request native squash auto-merge/merge-queue entry for eligible Dependabot PRs. Repository rules remain final authority.
- `release-please.yml` provides the shared release workflow for repositories that explicitly opt in. Release PRs pass normal repository protections before publication.
- `governance-drift-audit.yml` is detection-only for ruleset drift. Ruleset mutation remains an owner operation.

## Review automation

Automated AI reviews are advisory. This repository must not maintain a second merge-gating system around CodeRabbit, Copilot or Codex. Live GitHub protections and required CI decide merge eligibility.

## Credentials

GitHub App credentials used by shared Actions are supplied through organization Actions configuration. Canonical names are `GAMNACKEN_CLIENT_ID` and `GAMNACKEN_PRIVATE_KEY`.

Never commit credential values or expose them in logs, generated files, PR text or documentation.

## Validation

`.github/workflows/ci.yml` owns the terminal `CI / required` context for this repository. It validates workflow YAML, shell syntax and whitespace/conflict-marker errors without executing privileged organization automation.

Third-party GitHub Actions must be pinned to full commit SHAs.

When changing reusable workflows, verify caller references and generated artifacts affected by the change. When changing a required check name, verify the live ruleset uses the exact emitted context.
