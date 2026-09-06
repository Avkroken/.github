# AGENTS.md

Gemensamma regler för Avkrokens förråd.

Läs relevanta instruktioner och förrådets `REPO.md`, om den finns. `REPO.md` innehåller endast förrådsspecifika tekniska fakta.

## Arbete

- Förstå berörd kod, konfiguration, beroenden och validering innan du ändrar.
- Gör minsta säkra ändring. Undvik orelaterad städning, nya lager och beroenden.
- Kör relevant lokal validering innan du skapar eller uppdaterar en pull request.
- Ändra inte tester, säkerhet eller validering för att få något att passera.
- Uppdatera relevanta tester när beteendet ändras.
- Behandla extern data som opålitlig.
- Exponera eller committa aldrig hemligheter, tokens, nycklar eller känslig konfiguration.

## Grenar

- Namnge arbetsgrenar `<agent>/<typ>/<kort-beskrivning>`.
- Tillåtna typer: `fix`, `feat`, `docs`, `refactor`, `chore`, `security`, `infra`.
- Håll en logisk ändring per gren och pull request.
- Ändra inte `main` eller `dev` direkt.

## Normalflöde

Förråd som inte uttryckligen använder `dev`-piloten fortsätter med kortlivad arbetsgren och pull request till `main`.

Auto-merge med squash är standard. Aktivera den direkt när pull requesten är redo att mergas. Gör inget föregående status- eller ruleset-uppslag bara för att avgöra om auto-merge kan aktiveras.

Om GitHub direkt svarar `Pull request is in unstable status`, vänta 2 sekunder och gör exakt ett nytt försök. Gör inget status- eller ruleset-uppslag mellan försöken. Om det andra försöket misslyckas, eller GitHub returnerar ett annat fel, ska det konkreta felet styra eventuell vidare undersökning.

## Pilotflöde för `.github`

När `dev`-piloten är aktiverad i `Avkroken/.github` gäller detta i stället för normalflödet:

1. Gör ändringen på en kortlivad arbetsgren.
2. Kör relevant lokal validering.
3. Skapa pull requesten mot `dev` som draft.
4. Låt CodeRabbit granska draften och åtgärda relevant feedback.
5. Markera pull requesten Ready först när ändringen bedöms produktionsklar.
6. CodeRabbit ska ha godkänt aktuell kod och `CI / admission` ska passera.
7. Aktivera auto-merge med squash till `dev`.
8. När ändringen ligger på `dev` är programmerarens normala arbete klart.
9. Ett deterministiskt workflow skapar en oföränderlig promotion av endast de `dev`-commits som inte redan har promotats.
10. Promotionen går via merge queue. `CI / required` kör den fulla kontrollen på merge-gruppen mot aktuell `main`.
11. Grönt resultat mergas med squash till `main`.

`CI / admission` körs inte medan pull requesten är draft. Den startar först när programmeraren markerar ändringen Ready.

En misslyckad `CI / admission` gör pull requesten till draft igen. Den ska då behandlas som ofärdig kod, inte som något som ska studsa vidare genom fler kontroller.

Arbetsgrenar ska inte rutinmässigt synkas med `main`. Merge queue ansvarar för att verifiera den faktiska merge-kandidaten mot aktuell `main`.

Skapa inte vanliga feature-PR:er direkt mot `main` i pilotförrådet. Release- och andra uttryckligen deterministiska systemflöden får fortsätta rikta sig mot `main` när de är byggda för det.

## Kontroller

### `.github`-piloten

Mot `dev`:

- CodeRabbit använder Request Changes Workflow på draften. Fynd blockerar tills de är åtgärdade och boten godkänner aktuell kod.
- Ett godkännande krävs. Ny push gör tidigare godkännande inaktuellt.
- `CI / admission` är den required status check som kör snabb och deterministisk syntax-/strukturkontroll efter Ready.

Mot `main`:

- `CI / required` är required check. På vanlig PR är den billig; i `merge_group` kör den produktionskontrollen mot aktuell `main`.
- merge queue används.
- `Require branches to be up to date before merging` används inte.

### Övriga nuvarande required checks

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

Dessa övriga förråd behåller sitt nuvarande flöde tills piloten uttryckligen rullas ut vidare.

## Risk

Sätt exakt en risketikett på varje pull request, även när den är draft. Välj högsta tillämpliga nivå:

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

Exempel:

```bash
# Pilot: skapa arbets-PR som draft mot dev.
gh pr create --base dev --draft

# När programmeraren bedömer ändringen produktionsklar.
gh pr ready <PR> -R Avkroken/<FÖRRÅD>

# Standard efter att PR:n är Ready.
gh pr merge <PR> -R Avkroken/<FÖRRÅD> --auto --squash --delete-branch

# PR-läge när aktuell status faktiskt behövs.
gh pr view <PR> -R Avkroken/<FÖRRÅD> \
  --json state,isDraft,mergeable,mergeStateStatus,statusCheckRollup,reviewDecision,autoMergeRequest

# Obligatoriska kontroller när CI behöver felsökas.
gh pr checks <PR> -R Avkroken/<FÖRRÅD> --required
```

Kommandona är exempel, inte begränsningar. Använd annat när verkligheten kräver det.

### När ett färskt GitHub-uppslag är motiverat

Gör ett uppslag när uppgiften i sig kräver aktuell GitHub-information eller när GitHub har returnerat ett konkret problem, till exempel:

- hitta eller gå igenom öppna pull requests
- undersöka en misslyckad eller blockerad pull request
- läsa faktisk review-feedback
- felsöka en required check eller merge queue
- undersöka ett konkret fel från GitHub
- ändra GitHub-regler, workflows eller required checks
- kontrollera resultatet av en GitHub-administrativ ändring

Ett problem är anledning att undersöka problemet. Frånvaro av problem är inte anledning att kontrollera att inget problem finns.

## Kommentarer och granskning

- Läs relevant granskningsfeedback som faktiskt finns när uppgiften kräver arbete med pull requesten.
- Åtgärda konkreta fel och användbara förbättringar.
- I `dev`-piloten är CodeRabbits Request Changes/Approve-flöde en gate. Övriga AI- och botkommentarer är rådgivande om GitHub inte kräver annat.
- Jaga inte nya granskningar eller statusuppdateringar utan anledning.
- En gammal kommentar som redan är åtgärdad ska inte skapa mer arbete.

## Verifiering

- Kör relevanta tester och förrådets dokumenterade validering.
- Kontrollera diffen mot uppgiften.
- Verifiera tekniska förändringar på lämplig nivå.
- Låt GitHub hantera väntan på CI, merge queue och auto-merge.
- Gör inte statusuppslag bara för att se om något som GitHub redan hanterar har blivit klart.
