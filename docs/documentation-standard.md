# Avkrokens dokumentationsstandard

**Senast verifierad:** 2026-09-23

Det här dokumentet definierar den organisationsgemensamma modellen för publik, versionsstyrd projektdokumentation.

## Mål

Dokumentationen ska göra det möjligt att snabbt förstå:

- vad ett repository ansvarar för,
- hur systemet är uppbyggt,
- hur det körs och verifieras,
- vilka drift- och säkerhetsgränser som gäller,
- var aktuell teknisk current-state finns,
- vilka delar som är organisationsgemensamma respektive repo-specifika.

Publik repositorydokumentation ska beskriva state som kan verifieras från publika repositoryfiler eller publika externa källor. Extern konto-/providerstate ska inte kopieras in som current-state om den inte själv är publik. Historik finns i Git.

## Canonical källor

Ordningen är:

1. live provider-state när informationen gäller GitHub/Cloudflare-inställningar,
2. filer på repositoryts aktuella default branch,
3. `docs/project-context.md`,
4. övrig repositorydokumentation,
5. äldre issues, PR:er, chattar och exporter.

`README.md` och `docs/` på default branch är canonical publik projektdokumentation.

## README

README är en kort ingång, inte hela manualen. Den ska normalt innehålla:

- syfte och ansvar,
- viktigaste runtime-/plattformskomponenterna,
- hur projektet verifieras eller startas lokalt,
- länk till `docs/` eller konkreta dokument,
- länk till säkerhetsrapportering när relevant.

README ska använda relativa länkar till filer i samma repository.

## docs/

Komplexa repositories ska normalt ha:

- `docs/project-context.md` — repository-verifierbar teknisk state, viktiga invariants och externa kontrakt,
- `docs/architecture.md` — komponenter, dataflöden, trust boundaries och ansvar,
- `docs/operations.md` — verifiering, deploymentmodell, observability, migrations-/statehantering och felsökningsgränser.

Ytterligare ämnesspecifika dokument används när de tillför information utan att duplicera ovanstående.

Små repositories behöver inte konstgjort fylla alla dokument med text. De ska däremot ha tillräcklig dokumentation för att en ny maintainer ska kunna förstå ansvar, verifiering och drift utan att rekonstruera systemet från källkod.

## project-context

`docs/project-context.md` ska uppdateras när en materiell ändring påverkar exempelvis:

- runtime-arkitektur,
- integrationsgränser,
- Custom Properties eller ruleset-koppling,
- CI-/deploymentmodell,
- säkerhets- eller credentialmodell,
- lagring eller dataflöden,
- kritiska bygg- eller driftinvarianter.

Ta bort ersatt current-state i stället för att stapla nya varianter ovanpå gammal text.

## AGENTS.md

`AGENTS.md` är en kort agent-facing karta, inte en kopia av projektets dokumentation. Den ska:

- peka till central engineering-kontext och repo-specifik project-context,
- ange repositoryts viktigaste verifieringskommando/invariant,
- ange säkerhets- eller scopegränser som en agent alltid behöver känna till,
- hålla detaljer bakom länkar till `docs/` när de inte behövs för varje arbetsgren.

## GitHub Wiki

GitHub Wiki är en separat Git-yta från repositoryts vanliga default branch. Därför är Wiki **inte canonical source of truth** för Avkrokens tekniska dokumentation.

Om Wiki används ska den vara en presentations-/navigeringsyta och får inte innehålla unik current-state som saknas i repositoryt. Rekommenderad användning är en kort Home-sida som länkar till README, `docs/`, portal eller GitHub Pages.

Wiki ska inte användas för att kringgå PR-flöde, rulesets eller repositoryts versionsstyrda dokumentationsmodell.

## Portal och Pages

Avkrokens portal kan rendera publik Markdown direkt från publika repositories. GitHub Pages är en valfri separat presentationsyta för repositories som behöver en fristående dokumentations-URL.

Varken portal, Pages eller Wiki ändrar vilken källa som är canonical: det är fortfarande versionerad Markdown på default branch.

## Säkerhet

Publik dokumentation får inte innehålla:

- tokens eller secrets,
- privata nycklar,
- lösenord,
- känsliga authorization-listor eller credential-värden,
- privata runbooks som kräver konfidentialitet,
- information som medför att säkerhetsgränser kringgås.

Icke-hemliga resursnamn, bindings och arkitektur får dokumenteras när de behövs för att förstå systemet.

## Uppdateringskontrakt

När implementation, arkitektur eller drift ändras ska relevant dokumentation uppdateras i samma PR eller i en direkt efterföljande PR. En förändring är inte dokumentationsmässigt komplett om README eller canonical `docs/` fortfarande beskriver den tidigare modellen.
