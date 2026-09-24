# AGENTS.md

Det här repositoryt är Avkrokens centrala nod för organisationsgemensam GitHub-struktur, engineering-kontext och dokumentationsstandard.

## Läsordning

1. `docs/index.md` — central dokumentationskarta.
2. `docs/engineering-context.md` — organisationsgemensam engineering-current-state.
3. `docs/documentation-standard.md` — README/docs/Wiki-modellen.
4. `docs/repository-documentation.md` — integration mellan central nod och projektrepos.
5. berörda workflows, portal- eller standardfiler.

## Arbetsregler

- Utgå från aktuell default branch och arbeta i separat gren.
- Organisationsgemensamma förändringar görs här när de hör hemma centralt; duplicera dem inte repo för repo.
- Repo-specifik teknisk current-state hör hemma i respektive repositories `docs/`.
- README ska vara en kort ingång, inte en monolitisk manual.
- Wiki ska användas som navigations-/presentationsyta för icke-trivial dokumentation när det är rimligt, men versionsstyrd Markdown i huvudrepositoryt ska förbli reproducerbar källa.
- Ändringar i gemensam CI/governance ska verifieras mot faktisk GitHub-state; dokumentation är inte en ersättning för provider-state.
- Secrets, tokens, privata nycklar och konfidentiell information får aldrig läggas i publik dokumentation.
- Försvaga inte permissions, rulesets, CI eller säkerhetsgränser för att förenkla en ändring.
- Verifiera betydande ändringar före, under och efter implementation.
