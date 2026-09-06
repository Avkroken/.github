# Avkroken GitHub automation

Det här repositoryt innehåller Avkrokens centrala återanvändbara GitHub Actions-workflows och organisationsgemensamma agentkonfiguration.

## Princip

Använd GitHubs inbyggda funktioner, rulesets och etablerade standardflöden när de löser uppgiften. Egen automation ska endast finnas när den tillför en konkret funktion som inte redan hanteras bättre av GitHub eller ett befintligt verktyg.

CodeRabbit hanterar AI-baserad pull-request-granskning, risketiketter, pre-merge-kontroller och issue-enrichment enligt `.coderabbit.yaml`.

## Centrala workflows

- `.github/workflows/ci.yml` ger den snabba admission-kontrollen mot `dev` och den obligatoriska kontrollen för merge queue mot `main`.
- `.github/workflows/promote-dev.yml` promoverar godkända ändringar från `dev` till `main` via en oföränderlig promotion-PR.
- `.github/workflows/release-please.yml` innehåller det delade release-flödet.
- `.github/workflows/dependabot-automerge.yml` finns kvar som kompatibilitetsflöde för förråd som fortfarande använder det.
- `.github/workflows/sync-reusable-workflow-pins.yml` uppdaterar full-SHA-referenser för centrala reusable workflows som fortfarande kräver gemensam rollout.

## Visibility och secrets

Repositoryt är publikt. Innehållet ska därför alltid betraktas som offentligt.

Inga secrets, tokens, privata nycklar eller provider-credentials ska committas här.

Organisationsautomation som använder GitHub-appen Gamnacken använder `GAMNACKEN_CLIENT_ID` som Actions-variable och `GAMNACKEN_PRIVATE_KEY` som Actions-secret. Återanvändbara workflows som tar emot den privata nyckeln använder secret-namnet `app-private-key`.
