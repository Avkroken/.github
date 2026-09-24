# Avkroken/.github

`Avkroken/.github` är Avkrokens centrala publika repository för organisationsgemensam GitHub-struktur, engineering-standarder, community health-filer, återanvändbara workflows och dokumentationsnavigering.

Det ska **inte** ersätta projektrepositorynas egen dokumentation. Varje repo äger sin README och sin tekniska `docs/`-state; den centrala noden anger gemensam modell och hjälper läsaren hitta rätt.

## Börja här

- **[Dokumentationsnav](docs/index.md)** — central karta över standarder och projektdokumentation
- **[Dokumentationsmodell](docs/documentation-standard.md)** — README, `docs/`, Wiki och uppdateringskontrakt
- **[Engineering context](docs/engineering-context.md)** — organisationsgemensam teknisk kontext
- **[Repository-integration](docs/repository-documentation.md)** — hur varje repo kopplas till README, docs och Wiki

## Vad hör hemma här?

### Centralt

- gemensamma GitHub Actions/workflows
- organisationsprofil
- community health-filer
- gemensamma dokumentations- och engineering-standarder
- portalens kod
- navigation mellan publika repositories.

### Inte centralt

- ett projekts API-detaljer
- projektspecifika driftinstruktioner
- ett projekts interna dataflöden
- repo-specifika bygginvarianter.

Sådant hör hemma i respektive repository.

## Dokumentationsmodell

Varje icke-trivialt repository bör ha:

1. en kort och tydlig `README.md`;
2. en klickbar `docs/index.md`;
3. ämnesspecifika dokument under `docs/`;
4. GitHub Wiki som presentations-/navigationsyta när det är rimligt.

README ska hjälpa läsaren välja nästa klick, inte tvinga fram en lång scroll.

## Ärvda organisationsstandarder

Följande filer fungerar som standard för organisationens publika repositories när ett repository inte har en egen motsvarighet:

- `CODE_OF_CONDUCT.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `SUPPORT.md`
- `.github/FUNDING.yml`
- `.github/ISSUE_TEMPLATE/`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/DISCUSSION_TEMPLATE/`

Repository-specifika community health-filer har företräde.

## Portal

`portal/` innehåller Worker-projektet för `avkroken.denied.se`. Portalen läser publik repository-metadata och fungerar som projektkatalog; den ersätter inte README, docs eller Wiki.

## Integritetsgräns

Detta repository är publikt. Dokumentation och konfiguration får inte innehålla lösenord, tokens, privata nycklar, personuppgifter eller andra uppgifter som kräver konfidentialitet.
