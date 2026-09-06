# REPO.md

`Avkroken/.github` innehåller central återanvändbar GitHub-automation och gemensam förrådsmetadata. Gemensamma arbetsregler finns i `AGENTS.md`.

## Automation

- `.github/workflows/ci.yml` ger `CI / admission` mot `dev` och `CI / required` för promotion mot `main` och merge queue.
- `.github/workflows/promote-dev.yml` skapar deterministiska promotioner från `dev` till `main`.
- `.github/workflows/sync-reusable-workflow-pins.yml` rullar ut ändrade full-SHA-pins för de centrala reusable workflows som fortfarande behöver central rollout.
- `.github/workflows/dependabot-automerge.yml` är ett återanvändbart kompatibilitetsflöde för förråd som fortfarande anropar det.
- `.github/workflows/release-please.yml` innehåller det delade release-flödet för förråd som använder det.

## Credentials

Organisationens Actions-secrets använder namnen `GAMNACKEN_CLIENT_ID` och `GAMNACKEN_PRIVATE_KEY`. Återanvändbara workflows som tar emot en privat nyckel använder input-namnet `app-private-key`.

Credential-värden får aldrig skrivas till loggar, genererade filer eller förrådet.

## Validering

`.github/workflows/ci.yml` validerar workflow-YAML, shell-syntax samt whitespace- och conflict-marker-fel utan att köra privilegierad organisationsautomation.

Tredjeparts-GitHub Actions ska vara pinnade till fullständiga commit-SHA:n.
