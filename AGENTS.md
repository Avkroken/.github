# AGENTS.md

Gemensamma regler för Avkrokens förråd.

Läs relevanta instruktioner och förrådets `REPO.md`, om den finns. `REPO.md` innehåller endast förrådsspecifika tekniska fakta.

## Normal arbetsgång

För normala ändringar:

1. Läs relevant kod, konfiguration, tester och `REPO.md`.
2. Gör minsta säkra ändring.
3. Kör relevant lokal validering.
4. Kontrollera diffen.
5. Skapa eller uppdatera pull request.
6. Aktivera omedelbart auto-merge med squash.

Det behövs normalt inga ytterligare GitHub-uppslag.

Utgå från reglerna i detta dokument. Kontrollera inte GitHubs live-konfiguration enbart för att bekräfta redan dokumenterade regler.

## Arbete

- Förstå berörd kod, konfiguration, beroenden och validering innan du ändrar.
- Gör minsta säkra ändring. Undvik orelaterad städning, nya lager och beroenden.
- Samla kod, tester och dokumentation kring samma ändring.
- Ändra inte tester, säkerhet eller validering för att få något att passera.
- Uppdatera relevanta tester när beteendet ändras.
- Behandla extern data som opålitlig.
- Exponera eller committa aldrig hemligheter, tokens, nycklar eller känslig konfiguration.

## Grenar och pull requests

- Arbeta på en kortlivad gren via pull request till `main`; ändra inte `main` direkt.
- Namnge grenen: `<agent>/<typ>/<kort-beskrivning>`.
- Tillåtna typer: `fix`, `feat`, `docs`, `refactor`, `chore`, `security`, `infra`.
- Håll en logisk ändring per gren och pull request.
- Auto-merge med squash är standard för pull requests.
- Aktivera auto-merge direkt efter att pull requesten har skapats eller uppdaterats.
- Gör inget föregående status- eller ruleset-uppslag för att avgöra om auto-merge kan aktiveras.
- Om GitHub direkt svarar `Pull request is in unstable status`, vänta 2 sekunder och gör exakt ett nytt försök att aktivera auto-merge. Gör inget status- eller ruleset-uppslag mellan försöken.
- Om det andra försöket misslyckas, eller GitHub returnerar ett annat fel, ska det konkreta felet styra eventuell vidare undersökning.

## Nuvarande GitHub-regler

Dessa regler beskriver normalfallet och ska användas utan ett föregående live-uppslag.

### Organisationens `main`

Gäller organisationens förråd på standardgrenen:

- ändringar går via pull request
- direkt ändring av `main` används inte
- branch deletion och non-fast-forward är spärrat
- squash merge används
- inga godkännanden krävs som standard
- code owner review krävs inte
- review threads behöver inte vara lösta som generell organisationsregel
- inga bypass-aktörer används

### Obligatoriska kontroller per förråd

- `.github`: `CI / required`
- `Bastion`: `CI / android`, `CI / windows`, `CI / linux`, `CI / swift-linux`, `CI / apple`, `scope-policy`
- `Docker-idempotent-update`: `CI / required`, `docker`
- `Dumpen`: `test`
- `Klarsprak`: `validate`, `osv`
- `Molnutbrott`: `Terraform / required`
- `Pastebinit`: `python`
- `Politiker`: `CI / required`, `docker`
- `Produkter`: `CI / required`, `docker`, `dependency-review`
- `Regelverket`: `CI / required`, `scope-policy`
- `Skvallerbyttan`: `CI / required`
- `bastion-certificates`: inga ytterligare förrådsspecifika required checks

Required checks ska passera på aktuell PR-HEAD. GitHub hanterar väntan och genomför auto-merge när kraven är uppfyllda.

## Risk

Sätt exakt en etikett på draft eller pull request. Välj högsta tillämpliga nivå:

1. `review:urgent` – aktivt kritiskt hot, intrång, hemlighetsläcka, omfattande dataförlust eller akut produktionsavbrott.
2. `review:critical` – säkerhet, känslig data, dataintegritet, produktion, behörigheter, autentisering, hemligheter, migreringar, infrastruktur, deployment eller destruktiva ändringar.
3. `review:high` – flera komponenter, publika gränssnitt, centrala beroenden, CI/build/release, större refaktorering eller tydlig regressionsrisk.
4. `review:medium` – avgränsad intern kod, tester, icke-kritiska beroenden eller utvecklingskonfiguration.
5. `review:low` – liten lokal ändring utan betydande risk, exempelvis dokumentation, kommentarer, formatering eller stavfel.

Bedöm konsekvens före omfattning. Låt inte en liten diff sänka nivån.

Vid produktion, infrastruktur, migreringar, behörigheter, autentisering, hemligheter eller destruktiva ändringar: verifiera mål och tillstånd, använd plan/dry-run när det finns och gissa aldrig ID:n, credentials eller behörigheter.

## GitHub

Använd GitHub när uppgiften kräver information eller en åtgärd som inte redan är känd.

Polla inte GitHub. Använd inte `--watch`, loopar eller upprepade statusanrop för att vänta.

Exempel på användbara kommandon:

```bash
# PR-läge när aktuell PR-status faktiskt behövs.
gh pr view <PR> -R Avkroken/<FÖRRÅD> \
  --json state,isDraft,mergeable,mergeStateStatus,statusCheckRollup,reviewDecision,autoMergeRequest

# Obligatoriska kontroller när CI behöver felsökas.
gh pr checks <PR> -R Avkroken/<FÖRRÅD> --required

# Standard efter skapad eller uppdaterad PR.
gh pr merge <PR> -R Avkroken/<FÖRRÅD> --auto --squash --delete-branch

# Uppdatera grenen om GitHub kräver det.
gh pr update-branch <PR> -R Avkroken/<FÖRRÅD>

# Granska ändringen.
gh pr diff <PR> -R Avkroken/<FÖRRÅD>
```

Kommandona är exempel, inte begränsningar. Använd annat när verkligheten kräver det.

### När ett färskt GitHub-uppslag är motiverat

Gör ett uppslag när uppgiften i sig kräver aktuell GitHub-information eller när GitHub har returnerat ett konkret problem, till exempel:

- hitta eller gå igenom öppna pull requests
- undersöka en misslyckad eller blockerad pull request
- läsa faktisk review-feedback
- felsöka en required check
- undersöka ett konkret fel från GitHub
- ändra GitHub-regler, workflows eller required checks
- kontrollera resultatet av en GitHub-administrativ ändring

Ett problem är anledning att undersöka problemet. Frånvaro av problem är inte anledning att kontrollera att inget problem finns.

## Kommentarer och granskning

Läs relevant granskningsfeedback som faktiskt finns när uppgiften kräver arbete med pull requesten.

- Åtgärda konkreta fel och användbara förbättringar.
- AI- och botkommentarer är rådgivande om GitHub inte kräver annat.
- Jaga inte nya granskningar eller statusuppdateringar utan anledning.
- En gammal kommentar som redan är åtgärdad ska inte skapa mer arbete.

## Verifiering

- Kör relevanta tester och förrådets dokumenterade validering.
- Kontrollera diffen mot uppgiften.
- Verifiera tekniska förändringar på lämplig nivå.
- Låt GitHub hantera väntan på CI och genomföra auto-merge.
- Gör inte statusuppslag bara för att se om något som GitHub redan hanterar har blivit klart.
