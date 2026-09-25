# Documentation aggregate

Det här är bara implementationen för den centrala lässpegeln.

## Canonical ownership

Varje Avkroken-repository äger själv:

- README
- `docs/`
- Wiki
- Issues
- Discussions

`Avkroken/.github` är inte canonical källa.

## Hur speglingen fungerar

Workflowet:

1. upptäcker aktuella publika, icke-arkiverade Avkroken-repositories;
2. klonar deras default branch read-only;
3. samlar versionsstyrd Markdown;
4. klonar respektive Wiki read-only;
5. bygger en dokumentationsportal;
6. publicerar den som GitHub Pages artifact.

Genererad dokumentation committas aldrig tillbaka till `.github`.

## Trigger

- varje timme,
- manuellt,
- när aggregatorimplementationen ändras.

Ingen PAT behövs för att läsa publika repositories.
