# AGENTS.md

Det här repositoryt är Avkrokens centrala nod för organisationsgemensam GitHub-struktur, engineering-kontext och dokumentationsstandard.

## Läsordning

1. `docs/engineering-context.md` — current-state för CI, Custom Properties, rulesets och central teknisk styrning.
2. `docs/documentation-standard.md` — canonical dokumentationsmodell för Avkroken-repositories.
3. Repositoryts aktuella `README.md`, workflows och berörda källfiler.
4. GitHubs live-state när arbetet gäller settings, rulesets, Custom Properties eller andra organisationsinställningar.

## Arbetsregler

- Utgå från aktuell default branch och arbeta i separat gren: `{agent}/{feature}/{YYYY-MM-DD}/{HH-mm}-{id}`.
- Organisationsgemensamma ändringar görs här när de hör hemma centralt; duplicera dem inte repo för repo.
- Repo-specifik current-state hör hemma i respektive repositories `docs/project-context.md`.
- README ska vara en kort ingång. Utförlig canonical dokumentation ligger under `docs/`.
- GitHub Wiki får inte vara ensam eller canonical källa för arkitektur, drift, säkerhetsgränser eller current-state.
- Secrets, tokens, privata nycklar och annan konfidentiell information får aldrig läggas i publik dokumentation.
- Försvaga inte permissions, rulesets, CI eller säkerhetsgränser för att förenkla en ändring.
- Verifiera betydande ändringar före, under och efter implementation.
