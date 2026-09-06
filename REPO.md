# REPO.md

`Avkroken/.github` innehåller central återanvändbar GitHub-automation och gemensam förrådsmetadata. Gemensamma arbetsregler finns i `AGENTS.md`.

## Automation

- `.github/workflows/sync-reusable-workflow-pins.yml` och `.github/workflows/reconcile-reusable-workflow-pins.yml` uppdaterar SHA-pins till återanvändbara workflows.
- `.github/workflows/dependabot-automerge.yml` hanterar Dependabot-automation enligt workflowets villkor.
- `.github/workflows/release-please.yml` innehåller det delade release-flödet för förråd som använder det.
- `.github/workflows/governance-drift-audit.yml` upptäcker avvikelser i regler men ändrar dem inte.

## Credentials

Organisationens Actions-secrets använder namnen `GAMNACKEN_CLIENT_ID` och `GAMNACKEN_PRIVATE_KEY`. Återanvändbara workflows som tar emot en privat nyckel använder input-namnet `app-private-key`.

Credential-värden får aldrig skrivas till loggar, genererade filer eller förrådet.

## Validering

`.github/workflows/ci.yml` validerar workflow-YAML, shell-syntax samt whitespace- och conflict-marker-fel utan att köra privilegierad organisationsautomation.

Tredjeparts-GitHub Actions ska vara pinnade till fullständiga commit-SHA:n.
