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
6. genererar `search-index.json` för publik, access-filtrerad Portal-sökning;
7. publicerar spegeln och indexet som GitHub Pages artifact.

Genererad dokumentation committas aldrig tillbaka till `.github`.

## Trigger

- varje timme,
- manuellt,
- när aggregatorimplementationen ändras.

Ingen PAT behövs för att läsa publika repositories.


## Sökindex

`search-index.json` är en genererad read-only artefakt, inte source of truth.

Varje post anger:

- typ: repository, versionsstyrt dokument eller Wiki;
- canonical repository;
- ref där den kan fastställas;
- source path;
- canonical URL;
- titel;
- normaliserad publik söktext;
- om söktexten trunkerats.

Indexet byggs endast från samma publika, icke-arkiverade, icke-forkade repositories och Wikis som dokumentationsspegeln redan läser. Det innehåller inte skyddad Jobb-appdata från monorepot.
