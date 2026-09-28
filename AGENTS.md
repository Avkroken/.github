# AGENTS.md

## Syfte

Det här är Avkrokens publika GitHub-specialrepository för kontoprofil, community health-filer, mallar och enkel metadataautomation. Det är inte source of truth för fristående repositories.

## Regler

- Lägg inte applikationskod eller intern drift-/arkitekturdokumentation här.
- Fristående repositories äger själva sin tekniska current-state, README, `docs/`, workflows och repo-specifika instruktioner.
- Extern GitHub-governance är provider-state. Anta inte organization-scope, organization secrets eller andra org-funktioner utan live-verifiering.
- Lägg aldrig credentials, privata hostinventeringar eller andra interna operativa detaljer här.
- Utgå från aktuell default branch och arbeta i separat gren enligt `{agent}/{feature}/{YYYY-MM-DD}`.
- Commits ska använda Conventional Commits eller motsvarande tydlig typ, exempelvis `docs:`, `fix:`, `chore:` eller `ci:`.
- Läs hela PR-review-state före merge, inklusive kommentarer och trådar som GitHub markerar som `outdated`; verifiera att grundproblemet faktiskt är löst.
- Försvaga inte repositoryts ruleset eller säkerhetskrav för att få en ändring att passera.
