# Avkroken engineering context

Det här dokumentet är Avkrokens levande, versionsstyrda tekniska kontext för sådant som annars lätt blir gammalt i chattar eller agentminne: arbetsgrenar, Custom Properties, rulesets och CI-topologi.

**Senast verifierad:** 2026-09-18

## Auktoritet och läsordning

Vid konflikt gäller följande ordning:

1. GitHubs aktiva organisationsinställningar, Custom Properties och rulesets.
2. Filer på `main` i berörda repositories.
3. Det här dokumentet.
4. Äldre issues, pull requests, chattar och agentminnen.

Om punkt 1 eller 2 ändras ska det här dokumentet uppdateras i samma förändring eller i en direkt efterföljande PR. Dokumentet ska beskriva **nuvarande state**, inte samla gamla motstridiga varianter.

Repository-specifik kontext hör hemma i respektive repository, normalt i `docs/project-context.md`.

## Uppdateringskontrakt

Uppdatera det här dokumentet när någon av följande saker ändras:

- arbetsgrensnamn eller PR-flöde,
- betydelsen av en Custom Property,
- tillåtna värden i en Custom Property,
- hur ett ruleset väljer repositories,
- vilket workflow ett ruleset kräver,
- gränsen mellan centrala reusable workflows och required-workflow entrypoints,
- hur repo-specifik CI-konfiguration matas in,
- vilka domäner som räknas som `ci_stack` respektive `platform`.

Ersätt föråldrad current-state-text i stället för att lägga nya motsägelser ovanpå den. Historik finns i Git.

Planerade men ännu inte aktiva ändringar ska märkas **Planerad** eller **Pågående**.

Det här publika repositoryt får aldrig användas för hemligheter, tokens, privata nycklar eller andra konfidentiella värden.

## Arbetsgrenar och pull requests

Standard för automatiserade och agentdrivna arbetsgrenar:

```text
{agent}/{feature}/{YYYY-MM-DD}/{HH-mm}-{id}
```

Exempel:

```text
chatgpt/project-memory/2026-09-18/13-34-org
```

Utgå från repositoryts aktuella default branch, normalt `main`. Gör implementation i en separat arbetsgren och öppna PR mot `main`.

Force-push används inte om det inte uttryckligen behövs och har godkänts för den aktuella uppgiften.

## Custom Properties

Custom Properties beskriver repositories och används bland annat som selectors för organisations-rulesets. Skapa inte en ny property per CI-workflow när ett befintligt klassificeringsfält redan uttrycker rätt semantik.

### `ci_stack`

**Betydelse:** build/runtime stacks som används av repositoryts CI.

Kända och använda värden i nuvarande organisation:

- `swift`
- `rust`
- `dotnet`
- `gradle`
- `node`

Ett repository kan behöva flera stackvärden när det innehåller flera byggkedjor.

`ci_stack` ska beskriva språk/build-ekosystem, inte distributions- eller målplattformar.

Exempel på aktiv selector:

```text
main-swift
  default branch
  repository property: ci_stack = swift
```

### `platform`

**Betydelse:** plattformar som används av repositoryts builds och deployments.

GitHub-konfiguration verifierad 2026-09-18:

- typ: Multi select
- required: disabled
- repository actors may set property: disabled
- tillåtna värden:
  - `docs`
  - `windows`
  - `linux`
  - `android`
  - `apple`
  - `docker`
  - `cloudflare`

**Apple hör till `platform`, inte `ci_stack`.**

Samma princip gäller övriga plattformsbegrepp: klassificera efter vad värdet faktiskt betyder i stället för vilket workflow som råkar köra.

## Ruleset-modell

### Gemensamt `main`

Det generella `main`-rulesetet innehåller organisationsgemensamma skydd och kvalitetskrav för default branch.

Domänspecifika CI-krav hålls i separata rulesets så att de kan väljas via Custom Properties.

### Aktiva CI-rulesets

Verifierat mot Bastion 2026-09-18:

- `main-swift`
- `main-rust`
- `main-dotnet`
- `main-gradle`

De riktar sig mot default branch och kräver respektive workflow när repositoryt matchar selector-villkoret.

Exporten av `main-swift` visar den etablerade modellen:

```text
default branch
+ ci_stack = swift
+ required workflow .github/workflows/swift.yml
```

### Apple

**Planerad:** `main-apple`

Selector:

```text
platform = apple
```

Skapa inte en separat boolean som `ci_apple=true` när `platform=apple` redan uttrycker samma sak i den etablerade modellen.

## Central CI-arkitektur

`Avkroken/.github` innehåller centrala reusable workflows på `main`, bland annat:

- `.github/workflows/swift.yml`
- `.github/workflows/apple.yml`
- `.github/workflows/dotnet.yml`
- `.github/workflows/gradle.yml`
- `.github/workflows/rust.yml`
- `.github/workflows/node.yml`
- `.github/workflows/python.yml`
- `.github/workflows/docker.yml`
- `.github/workflows/cloudflare.yml`

De centrala Swift/Apple/.NET/Gradle/Rust-workflowsen är implementationslager som kan anropas via `workflow_call`.

### Reusable workflow är inte samma sak som required-workflow entrypoint

Ett workflow som endast definierar `workflow_call` ska behandlas som återanvändbar implementation.

När ett organisations-ruleset ska kräva central CI ska det finnas ett tydligt required-workflow entrypoint som:

1. triggas på de events som rulesetet ska validera, normalt PR/merge queue,
2. kör i det valda repositoryts kontext,
3. anropar den centrala reusable implementationen,
4. matar in repo-specifika paths/schemes/flags utan att duplicera implementationslogiken.

Håll entrypoint tunt. Den centrala reusable workflowen ska innehålla själva bygg- och testlogiken.

### Repo-specifik CI-konfiguration

Föredra explicita reusable-workflow inputs och repository Actions variables för repo-specifika värden som:

- working directory,
- Xcode project path,
- Xcode schemes,
- Gradle root,
- .NET test project,
- Rust working directory,
- systempaket.

Kopiera inte hela centrala workflows till varje repository enbart för att ändra paths.

### Permissions

En caller måste ge minst den permission-ceiling som en kallad reusable workflow behöver. GitHub validerar permissions-kedjan redan vid workflow-start.

Exempel: om ett centralt Gradle-jobb kan deklarera `contents: write` för dependency submission måste caller/required-entrypoint tillåta den nivån.

### Shell-säkerhet

Interpolera inte externa eller konfigurerbara Actions-uttryck direkt i `run:` när värdet kan innehålla shell-data.

Undvik:

```yaml
run: tool "${{ inputs.value }}"
```

Föredra:

```yaml
env:
  VALUE: ${{ inputs.value }}
run: tool "$VALUE"
```

Den här regeln infördes efter att CodeQL korrekt flaggade workflow-input injection i centrala Apple/.NET/Rust-workflows.

## Repository-specifik projektkontext

Ett repository med komplex CI eller flera plattformar bör ha:

```text
docs/project-context.md
```

Den filen ska beskriva endast repositoryts egen state och länka tillbaka hit för organisationsregler.

Agentinstruktioner, README eller motsvarande bör hänvisa till projektkontexten så att den läses före större ändringar.

## Checklista vid CI-/ruleset-ändring

Innan en ändring betraktas som klar:

- verifiera rätt Custom Property och rätt semantiskt värde,
- verifiera att selector träffar avsedda repositories och inget annat,
- verifiera default-branch-target,
- verifiera workflow source/path/ref,
- verifiera permission ceiling,
- verifiera att shell-inputs inte introducerar CodeQL injection,
- kör workflowet mot ett riktigt repository innan gamla vägen tas bort,
- uppdatera det här dokumentet och berörda `docs/project-context.md`.
