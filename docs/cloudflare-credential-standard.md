# Cloudflare credential standard

**Status:** Planerad  
**Senast verifierad:** 2026-09-19

Det här dokumentet definierar Avkrokens organisationsgemensamma modell för Cloudflare Account API Tokens. Modellen är en styrningsstandard för behörighetsklasser och resource scope. Den innehåller inga tokenvärden, account-ID:n, privata appnamn, exakta GitHub secret-namn eller andra operativa hemligheter.

Aktuell faktisk Cloudflare-konfiguration vinner alltid över detta dokument. Vid tokenutgivning ska Cloudflares live-dashboard och den genererade **Token Summary** verifieras innan tokenet skapas, eftersom Cloudflare kan ändra innehållet i standardtemplates utan att äldre dokumentation uppdateras samtidigt.

## Mål

Standardmodellen ska:

- ersätta appunika Cloudflare API-token där en delad credentialklass är tillräcklig,
- hålla antalet långlivade credentials litet och begripligt,
- återanvända Cloudflares standardtemplates när de träffar Avkrokens behov rimligt väl,
- tillåta medvetet behörighetsöverskott när det ger enklare och stabilare drift,
- skilja normal läsning, känsligare observation, säkerhetsläsning, normal skrivning och administrativ konfiguration,
- separera tokenadministration från all normal applikations- och driftåtkomst,
- stödja central rotation utan att permissionsdesign och credentialrotation blandas ihop.

## Grundmodell

Read-klasserna är både **partitionerade** och **rangordnade**:

```text
R1 < R2 < R3
```

Högre nummer betyder känsligare eller mer privilegierad informationsyta. Det betyder **inte** arv eller superset.

```text
R1 ∩ R2 = ∅
R2 ∩ R3 = ∅
R3 innehåller inte automatiskt R1 eller R2.
```

En konsument som behöver funktioner från flera read-klasser får flera credentials och väljer rätt credential för respektive API-operation.

Write/operations följer motsvarande princip:

```text
W1 < O1
```

W1 är normal Developer Platform-write. O1 är högre klassad infrastruktur-, edge- och säkerhetsadministration. O1 är inte ett superset av W1.

Tokenadministration ligger helt utanför R/W/O-modellen.

## Resource scope

De delade organisationscredentialsen ska normalt använda:

- **Entire Account** för account-scopade permission groups.
- **All Domains / all zones** för zone-scopade permission groups.

Cloudflares granulariteter för **Specified Domains**, **Specified Workers**, specifika R2-buckets och andra individuella resurser används endast när det finns ett uttryckligt behov av en specialcredential. De ska inte vara standard för organisationsgemensamma klasser.

Resource scope och permissionklass är separata axlar. Samma permission group kan förekomma med olika resources, och specifika Workers/R2-buckets kan exponera andra permission groups än account-wide motsvarigheter.

## R1 — Platform / Resource Read

R1 är normal teknisk läsning av Cloudflares Developer Platform och grundläggande resursinventering.

R1 skapas som **Custom Account API Token**. Nuvarande Cloudflare-template **Read all resources** är avsiktligt för bred för R1 eftersom den skulle kollapsa separationen mellan R1, R2 och R3.

Kanonisk R1-bas:

- Zone Read
- Workers Scripts Read
- D1 Read
- Workers KV Storage Read
- Workers R2 Storage Read

Nya read-permissions läggs i R1 när de huvudsakligen beskriver normal plattform/resource state och inte exponerar tydligt känsligare observability-, operations-, security- eller identity-data.

## R2 — Analytics / Observability / Operations Read

R2 är högre klassad än R1 och omfattar analytics, telemetry, audit-/operationsobservation och liknande driftinsyn.

Förstahandsbas är Cloudflares live-template **Read analytics**. Live-templateinnehållet ska granskas i Token Summary vid skapandet; det som saknas från nedanstående capability-bas läggs till explicit.

Kanonisk R2-capability-bas:

- Account Analytics Read
- Workers Observability Read
- Workers Observability Telemetry Write
- Notifications Read
- Account Settings Read

`Workers Observability Telemetry Write` ligger funktionellt i R2 trots Cloudflares Write-etikett när den används för telemetry query/observation. Den ska inte användas som prejudikat för att lägga vanliga muterande write-permissions i read-klasser.

Permissions som följer med Cloudflares **Read analytics**-template accepteras som template-bundled permissions även när alla inte används av varje konsument.

## R3 — Security / Identity Read

R3 är högst rankad read-klass och omfattar säkerhets-, access-, Zero Trust- och identitetsobservation.

Förstahandsbaser är Cloudflares live-templates **Security** och **Zero Trust**. Live-templateinnehållet ska granskas vid skapandet. Saknade verifierade capabilities läggs till explicit.

Kanonisk R3-capability-bas:

- Access: Apps and Policies Read
- Cloudflare Tunnel Read
- Zero Trust Read
- Bot Management Read
- Zone WAF Read

R3 ska inte automatiskt innehålla samtliga Access-, Zero Trust-, WAF- eller security-permissions. Nya permissions placeras här först när en faktisk konsument behöver den informationsytan eller när de följer med en vald Cloudflare-standardtemplate.

## W1 — Developer Platform Write

W1 är den normala delade skrivcredentialen för Cloudflares Developer Platform.

Förstahandsbas är Cloudflares live-template **Edit Cloudflare Workers**.

Den live-template som verifierades 2026-09-19 innehöll:

### Zone

- Workers Routes Write

### Account

- Workers KV Storage Write
- Workers Scripts Write
- Account Settings Read
- Workers Tail Read
- Workers R2 Storage Write
- Pages Write
- Workers CI Write
- CF Agents Write
- Workers Observability Write
- Workers Containers Write

Avkrokens verifierade tillägg utöver denna template är:

- D1 Write
- Queues Write
- Browser Run Write

Template-bundled read-permissions behålls. W1 ska inte kompletteras med edge-/security-administration enbart för bekvämlighet.

## O1 — Infrastructure / Security Administration

O1 är högre klassad än W1 och används för Cloudflare-konfiguration utanför normal Developer Platform-write.

Verifierad standardtemplate-komponent:

- **Edit Zone DNS**
  - DNS Write

Kanonisk O1-capability-bas utöver template-komponenten:

- Bot Management Write
- Zone WAF Write
- Secrets Store Write

Cloudflares live-template **Zone Administration** är en kandidat för framtida användning i O1, men ska inte göras till kanonisk bas förrän dess aktuella Token Summary har verifierats mot O1-gränsen.

Account API Tokens Write får aldrig läggas i O1.

## Token administration

Tokenadministration är ett separat control plane och får inte delas med applikationsruntime, normal Developer Platform-write eller O1.

Cloudflares live-template **Create Account Tokens** är den avsedda template-basen när programmatisk tokenadministration faktiskt behövs.

Denna credential:

- ska hållas separat från R1/R2/R3/W1/O1,
- ska inte distribueras till vanliga repositories eller Workers,
- ska inte användas som generell admincredential,
- ska inte skapas alls om token lifecycle kan hanteras tillräckligt via Cloudflare Dashboard.

## Credentialdistribution

GitHub Organization Secrets är den centrala credentialkällan för GitHub-hostade workflows som behöver en viss klass. Repositoryåtkomst till ett org-secret ska begränsas till de repositories som faktiskt behöver klassen.

Cloudflare Secrets Store är den föredragna centrala credentialkällan för Worker-runtime när en Worker behöver konsumera en delad secret. Secrets Store-bindings är separata från vanliga Worker **Variables and Secrets** och konsumeras genom respektive binding-API.

Exakta secret-namn, repositorytilldelningar, tokenvärden och operativ migreringsordning dokumenteras inte i detta publika repository.

## Kodkontrakt

Ett enskilt Cloudflare API-anrop använder ett Bearer-token. En applikation som behöver flera credentialklasser får därför flera bindings/env-inputs och väljer rätt credential per API-operation.

Kod ska inte:

- försöka slå ihop tokenvärden,
- anta att R3 innehåller R2/R1,
- anta att O1 innehåller W1,
- använda O1 eller token-admin som fallback när en lägre klass saknar permission,
- hårdkoda credentialvärden.

En 403 från en lägre klass är en signal att permissionmappningen ska utvärderas, inte att koden automatiskt ska falla tillbaka till en bredare credential.

## Templatepolicy

Prioritetsordningen vid ny eller ändrad credentialklass är:

1. verifiera faktisk konsumentfunktion och API-endpoint,
2. kontrollera Cloudflares aktuella live-templatekatalog,
3. använd en standardtemplate som bas när den träffar klassen rimligt väl,
4. acceptera måttligt template-bundet permissionöverskott,
5. lägg till saknade permissions explicit,
6. skapa en ny klass endast när behovet utgör en egen funktionell och högre/lägre rang, inte för en enstaka permission.

Cloudflares live Token Summary är source of truth för templateinnehåll vid skapandet. Äldre dokumentation eller tidigare exporter används som referens men får inte överstyra live-state.

## Migration från äldre appunika tokens

Migration sker utan att ändra befintliga credentials först:

1. skapa de nya Account API Tokens med slutlig klass och slutligt namn,
2. skapa de centrala credentialvärdena i respektive godkänd secret store,
3. ge endast berörda konsumenter tillgång,
4. migrera en konsument i taget,
5. verifiera API-funktion, deployment/runtime och felvägar,
6. observera att den gamla credentialen inte längre används,
7. revokera först därefter den gamla tokenen.

**Roll** används inte som migreringsmekanism. Roll roterar secretvärdet för samma tokenobjekt och används först när en etablerad credential ska roteras utan att ändra dess permissionmodell.

Permissionsändring och credentialrotation ska behandlas som separata operationer.

## Verifiering

Varje klassändring följer tre steg:

### Före

- verifiera Cloudflare live-template och Token Summary,
- verifiera aktuell konsumentkod och endpoint,
- verifiera resource scope,
- verifiera var credentialen distribueras.

### Under

- verifiera den nya credentialen mot avsedd operation innan gammal credential tas bort,
- verifiera att konsumenten inte använder en högre klass som oavsiktlig fallback,
- verifiera att inga tokenvärden loggas eller skrivs till repository.

### Efter

- verifiera lyckade API-anrop/deployments,
- verifiera relevanta provider-health/capability checks,
- verifiera att gammal credential inte längre behövs,
- revokera överflödig credential först efter lyckad konsumentverifiering.

## Källor och current-state

Den här modellen bygger på:

- Cloudflares live Account API Token-dashboard och Token Summary verifierade 2026-09-19,
- aktuell permissionyta för Entire Account, all zones, specific zone, specific Workers och R2 buckets,
- Cloudflares live standardtemplates, inklusive Edit Cloudflare Workers och Edit Zone DNS,
- verifierad användning i Avkrokens aktuella repositorykod.

Cloudflares publika API-token-template-dokumentation är kompletterande källa. Om dokumentationen och live-dashboarden skiljer sig vinner live-dashboarden för faktisk tokenutgivning.
