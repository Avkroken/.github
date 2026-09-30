# AGENTS.md

## Syfte

Det här är Avkrokens publika GitHub-specialrepository för kontoprofil, community health-filer, mallar och enkel metadataautomation. Det är inte source of truth för fristående repositories.

## Regler

- Lägg inte applikationskod eller intern drift-/arkitekturdokumentation här.
- Fristående repositories äger själva sin tekniska current-state, README, `docs/`, workflows och repo-specifika instruktioner.
- Extern GitHub-governance är provider-state. Anta inte organization-scope, organization secrets eller andra org-funktioner utan live-verifiering.
- Lägg aldrig credentials, privata hostinventeringar eller andra interna operativa detaljer här.
- Utgå från aktuell default branch och arbeta i separat gren enligt `{agent}/{feature}/{date}`, där `date` skrivs som `YYYY-MM-DD`.
- Arbetet ska vara seriellt och semantiskt per repository: en arbetsgren/PR motsvarar en sammanhängande feature eller uppgift, och `feature`-delen ska beskriva arbetet semantiskt.
- Innan agenten påbörjar nästa uppgift i samma repository ska befintlig öppen arbetsgren, draft eller PR färdigställas genom relevanta checks, reviews och merge, eller uttryckligen avslutas/blockeras. Skapa inte tids-/ID-suffix eller parallella branchvarianter för att kringgå ett upptaget namn.
- Om `{agent}/{feature}/{date}` redan finns för uppgiften ska agenten fortsätta den befintliga arbetslinjen i stället för att skapa en ny.
- Commits ska använda Conventional Commits eller motsvarande tydlig typ, exempelvis `docs:`, `fix:`, `chore:` eller `ci:`.
- Läs hela PR-review-state före merge, inklusive kommentarer och trådar som GitHub markerar som `outdated`; verifiera att grundproblemet faktiskt är löst.
- Avkrokens aktiva repositories ska använda den centrala agent-auto-merge-policyn i `.github/workflows/agent-automerge-policy.yml`. Repo-caller får endast ge `contents: write` och `pull-requests: write`; policyn ska bara aktivera GitHubs native auto-merge för `gamnacken[bot]`-skapade same-repo `codex/*`-PR:er mot default branch.
- Försvaga inte repositoryts ruleset eller säkerhetskrav för att få en ändring att passera.

## Agent skills

This repository is a deliberate exception to the normal `docs/agents/*` layout because its public repository-boundary check forbids a root `docs/` tree.

### Issue tracker

GitHub Issues is the canonical issue and specification tracker for this repository. Read the full issue, labels, comments, linked pull requests, sub-issues, and native dependencies before acting. Pull requests remain implementation/review artifacts rather than a replacement issue tracker.

### Domain docs

Treat this repository as a single-context metadata repository. Use the established vocabulary in `AGENTS.md`, `README.md`, and other allowed root/profile documentation. If a change conflicts with an existing recorded decision, surface the conflict explicitly. Do not create placeholder `CONTEXT.md` or forbidden `docs/` content merely to satisfy a generic skill convention.

