# AGENTS.md

This repository is Avkroken's central source for shared GitHub metadata automation. Keep changes minimal, reviewable, and free of secrets.

## Metadata automation

`.github/workflows/metadata-routing.yml` is deterministic metadata automation. It may assign `blixten85`, validate classification labels, and derive `agent:*`, `priority:*`, and `triage:*` labels. It must not check out or execute pull-request code.

## Metadata-only AI triage exception

GitHub Agentic Workflows are allowed only for metadata-only issue triage under these constraints:

- The agent may read the triggering issue and read-only repository context needed to classify it.
- Safe outputs may add exactly one `difficulty:*` label and exactly one `security:*` label from the centrally documented allowlist.
- The agent portion must remain read-only; label mutation must occur through `gh-aw` safe outputs.
- The workflow must not comment, assign users or coding agents, create or update branches or pull requests, edit or close issues, perform review, merge, deploy, start a coding-agent session, or propose/perform remediation.
- Copilot inference may use either organization billing or the GitHub Actions secret `COPILOT_GITHUB_TOKEN`. If the PAT-backed path is used, the secret must contain a user-owned fine-grained PAT scoped only for Copilot Requests and must be configured in GitHub UI; never commit or paste the token into repository content.
- Do not add external AI-provider credentials without separate explicit owner approval.
- Keep the `.md` source and generated `.lock.yml` together. Compile with the official `github/gh-aw` toolchain and review generated permissions, actions, containers, and safe-output policy before merge.

This exception does not relax any other prohibition on AI remediation, review automation, branch/PR mutation, deployment, or credential use.

## Repository hygiene

Use branches and pull requests for changes to `main`. Respect live rulesets and required checks. Never commit secrets, tokens, private keys, provider credentials, or sensitive organization data; this repository is public.
