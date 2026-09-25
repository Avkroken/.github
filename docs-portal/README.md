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
3. samlar root-dokument och `docs/`; monorepots `apps/**` speglas aldrig av den generiska aggregatoren;
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

Indexet byggs endast från publika, icke-arkiverade, icke-forkade repositories och Wikis som klarar indexpolicyn.

`Avkroken/Avkroken` exkluderas strukturellt från det generiska sökindexet. Monorepot innehåller både publika och skyddade appytor, och en repo-generisk indexerare får därför inte försöka avgöra access genom textfiltrering. Portalens söklager får i stället lägga till uttryckligen publicerade appkällor via appens `portal.public.json`-gräns.

Den generiska dokumentationsspegeln tar inte med `apps/**`. Detta gäller även nested `README.md`, så `apps/jobb/README.md` eller `apps/jobb/docs/**` kan inte publiceras via Pages-aggregatoren.
