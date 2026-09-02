# GITHUB.md

This is the repository governance document for `Avkroken/.github`. Binding AI coding-agent policy is defined only in `Avkroken/.github/AGENTS.md`; this document records repository-specific technical contracts, invariants, validation requirements, and operational context required by that policy. It must not define, supplement, narrow, or override agent policy.

This repository is Avkroken's central source for shared GitHub metadata and repository-policy automation. Keep changes minimal, reviewable, and free of secrets.

## Metadata automation

`.github/workflows/metadata-routing.yml` is deterministic metadata automation. It may assign `blixten85`, validate classification labels, convert one temporary `classification:<difficulty>:<security>` label into canonical classification labels, and derive `agent:*`, `priority:*`, and `triage:*` labels. It must not check out or execute pull-request code.

Canonical `difficulty:*` and `security:*` labels take precedence over AI output. The temporary `classification:*` label is transport metadata only and must be removed after deterministic conversion. Malformed or conflicting classification metadata must fail closed to `triage:invalid`.

## Metadata-only AI triage exception

GitHub Agentic Workflows are allowed only for metadata-only issue triage under these constraints:

- The agent may read the triggering issue and read-only repository context needed to classify it.
- Safe outputs may add exactly one temporary `classification:<difficulty>:<security>` label from the centrally documented allowlist. The agent must not directly write canonical `difficulty:*` or `security:*` labels.
- The agent portion must remain read-only; temporary label mutation must occur through `gh-aw` safe outputs and deterministic routing must perform canonical conversion.
- Missing-tool, missing-data, incomplete-report, noop and workflow-failure fallbacks must not create issues or other repository records.
- The workflow must not comment, assign users or coding agents, create or update branches or pull requests, edit or close issues, perform review, merge, deploy, start a coding-agent session, or propose/perform remediation.
- Callers must explicitly map only `COPILOT_GITHUB_TOKEN`; `secrets: inherit` is prohibited for AI triage.
- Copilot inference may use either organization billing or the GitHub Actions secret `COPILOT_GITHUB_TOKEN`. If the PAT-backed path is used, the secret must contain a user-owned fine-grained PAT scoped only for Copilot Requests and must be configured in GitHub UI; never commit or paste the token into repository content.
- Do not add external AI-provider credentials without separate explicit owner approval.
- Keep the `.md` source and generated `.lock.yml` together. Compile with the official `github/gh-aw` toolchain and review generated permissions, actions, containers, safe-output cardinality and failure behavior before merge.

This exception does not relax any other prohibition on AI remediation, review automation, deployment, or credential use.

## Dependabot and merge-queue platform exception

The repository owner explicitly authorizes deterministic, non-AI automation for dependency maintenance and centrally managed merge-queue policy.

- `.github/workflows/dependabot-automerge.yml` is the reusable implementation. It may use the organization-installed `Gamnacken` GitHub App to request native GitHub auto-merge / merge-queue entry only for non-draft pull requests authored by `dependabot[bot]`.
- The Dependabot workflow must not check out or execute pull-request code, bypass rulesets, use administrator merge, update PR branches, rebase branches, dismiss reviews, or directly merge around the merge queue.
- Repository callers may trigger the reusable workflow on Dependabot PR events and on a low-frequency reconciliation schedule so missed events do not create permanent backlog.
- `.github/workflows/ruleset-sync.yml` may reconcile only the repositories explicitly listed in `rulesets/merge-queue.json`, using the canonical repository-level merge-queue ruleset in that file.
- `ruleset-sync.yml` may also move the organization `main` ruleset's required OSV workflow source to this repository and remove the redundant OSV status-check entry when the required-workflow rule is authoritative.
- Repository rulesets remain the final merge authority. No automation in this repository may create bypass actors or weaken required project-specific CI/security gates.
- GitHub App credentials must be supplied only through organization Actions configuration using `GAMNACKEN_ID` and `GAMNACKEN_PEMKEY`; credential values must never be committed or printed.

## Repository hygiene

Use branches and pull requests for changes to `main`. Respect live rulesets and required checks. Never commit secrets, tokens, private keys, provider credentials, or sensitive organization data; this repository is public.
