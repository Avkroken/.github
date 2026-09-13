# Avkroken/.github

Centralt organisationsrepository för Avkroken. Här finns gemensamma GitHub-standarder, organisationsprofilen och koden för `avkroken.denied.se`.

## Ärvda organisationsstandarder

Följande filer fungerar som standard för organisationens publika repositories när ett repository inte har en egen motsvarighet:

- `CODE_OF_CONDUCT.md` — gemensam uppförandekod.
- `CONTRIBUTING.md` — gemensamma riktlinjer för bidrag.
- `SECURITY.md` — gemensam policy för säkerhetsrapportering.
- `SUPPORT.md` — gemensam vägledning för frågor och support.
- `.github/FUNDING.yml` — GitHub Sponsors-konfiguration.
- `.github/ISSUE_TEMPLATE/` — formulär och länkar för issues.
- `.github/PULL_REQUEST_TEMPLATE.md` — standardmall för pull requests.
- `.github/DISCUSSION_TEMPLATE/` — formulär för organisationens Discussions.

Repository-specifika community health-filer har företräde framför motsvarande organisationsstandard.

## Repo-lokal GitHub-konfiguration

Följande gäller detta repository och är inte automatiskt organisationsgemensamma standarder:

- `CODEOWNERS` — ägarskap för filer i detta repository.
- `.github/labeler.yml` — labeler-regler för detta repository.
- `.github/workflows/labeler.yml` — PR-labeler för detta repository.
- `profile/README.md` — publik organisationsprofil på GitHub.
- `docs/` — publik teknisk dokumentation.

## Arbetsflöde

Utgå från den aktuella `main`-grenen och gör ändringar i en separat arbetsgren. Automatiserade arbetsgrenar använder normalt namnformen `codex/{feature}/{date}/{time}`.

Pull requests öppnas mot `main`. Låt repositoryts automatiska kontroller och regler bli gröna före merge. Arbetsgrenar raderas efter merge.

## Portal

Portalen läser endast **publika**, ej arkiverade repositories i GitHub-organisationen.

För att visa ett repository på `avkroken.denied.se`:

1. Sätt repositoryts **Website**-fält till den publika webbplatsens **HTTPS-URL** (`https://...`). `http://` publiceras inte i portalen.
2. Lägg till en kategoritopic: `project`, `tool`, `docs`, `service` eller `experiment`. Kategorin fungerar samtidigt som publiceringsmarkör för portalen.
3. Lägg valfritt till en accenttopic: `cyan`, `blue`, `violet`, `magenta` eller `pink`.
4. Använd repositoryts description som text på portalkortet.

Äldre `portal-*`-varianter för kategori och accent stöds tills vidare för bakåtkompatibilitet, men nya ändringar bör använda de kortare topic-namnen ovan.

Ta bort kategoritopicen för att dölja webbplatsen från portalen. Ingen ny deploy krävs för rena metadataändringar. Workern cachelagrar GitHub-metadata i 5 minuter.

## Integritetsgräns

Portalens indexering använder GitHubs publika repository-metadata. Detta repository är också publikt, så dokumentation och konfiguration här får inte innehålla lösenord, tokens, privata nycklar, personuppgifter eller andra uppgifter som kräver konfidentialitet.

Detaljer som endast behövs för privat drift eller intern säkerhetsadministration ska hållas utanför detta publika repository.

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
