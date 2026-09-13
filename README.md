# Avkroken/.github

Centralt organisationsrepository för Avkroken. Här finns GitHub-standarder som ska vara gemensamma mellan organisationens repositories samt koden för `avkroken.denied.se`.

## Organisationsstandard

Filerna nedan fungerar som standard för repositories som inte har en egen motsvarighet:

- `.github/FUNDING.yml` — GitHub Sponsors-konfiguration.
- `.github/ISSUE_TEMPLATE/` — gemensamma formulär för felrapporter och förbättringsförslag.
- `SECURITY.md` — gemensam policy för privat rapportering av säkerhetsproblem.
- `.github/labeler.yml` — labeler-regler för detta repository och bas för repo-specifika regler.
- `.github/workflows/labeler.yml` — PR-labeler för detta repository.
- `profile/README.md` — publik organisationsprofil på GitHub.

Repo-specifika community health-filer har företräde framför standarderna i detta repository.

## Arbetsflöde

Ändringar görs på `dev` och förs till `main` via pull request. `main` är repositoryts default branch och den gren som GitHub använder för organisationsstandarderna.

## Portal

Portalen läser endast **publika** repositories i GitHub-organisationen.

För att visa ett repository på `avkroken.denied.se`:

1. Sätt repositoryts **Website**-fält till den publika webbplatsens URL.
2. Lägg till topic `avkroken-portal`.
3. Använd repositoryts description som text på portalkortet.

Valfria kategoritopics:

- `portal-project`
- `portal-tool`
- `portal-docs`
- `portal-service`
- `portal-experiment`

Valfria accenttopics:

- `portal-cyan`
- `portal-blue`
- `portal-violet`
- `portal-magenta`
- `portal-pink`

Ta bort `avkroken-portal` för att dölja webbplatsen igen. Ingen ny deploy krävs. Workern cachelagrar GitHub-metadata i 5 minuter.

## Integritetsgräns

Workern använder GitHubs publika endpoint för organisationsrepositories med `type=public`. Privata Cloudflare Tunnel/Access-hostnames lagras inte i detta repository och upptäcks inte av portalen.

## Cloudflare

Använd `portal/` som Worker-projektets root.

Workern serverar:

- `/`
- `/avkroken-login-logo.svg`
- `/access-denied.svg`
- `/access-denied/`
- `/api/sites`

D1, KV och R2 behövs inte.

Ett valfritt `GITHUB_TOKEN` kan läggas till som Worker secret för autentiserade GitHub API-anrop. Det behövs inte för publik repository-metadata.
