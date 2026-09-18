# Avkroken engineering context

Det här dokumentet är Avkrokens levande, versionsstyrda tekniska kontext för arbetsgrenar, Custom Properties, rulesets och central CI-topologi.

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
- hur central issue/PR-triage och auto-assignment är kopplad mellan source-repository och callers,
- hur publik projektdokumentation upptäcks, renderas och vid behov publiceras med GitHub Pages,
- hur portalens dokumentationsnav hämtar endast publika repositorykällor,
- vilka domäner som räknas som `ci_stack` respektive `platform`.

Ersätt föråldrad current-state-text i stället för att lägga nya motsägelser ovanpå den. Historik finns i Git.

Planerade men ännu inte aktiva ändringar ska märkas **Planerad** eller **Pågående**.

Det här publika repositoryt får aldrig användas för hemligheter, tokens, privata nycklar eller andra konfidentiella värden.

## Arbetsgrenar och pull requests

Standard för automatiserade och agentdrivna arbetsgrenar:

```text
{agent}/{feature}/{YYYY-MM-DD}/{HH-mm}-{id}
```

Utgå från repositoryts aktuella default branch, normalt `main`. Gör implementation i en separat arbetsgren och öppna PR mot `main`.

Force-push och history rewrite används inte.

## Central GitHub architecture

`Avkroken/.github` is the organization-level source of truth for reusable CI implementation and ruleset-required workflow entrypoints.

Repositories are selected into organization rulesets through GitHub Custom Properties. The current conventions are:

- `ci_stack` selects build/runtime stacks such as `swift`, `rust`, `dotnet`, `gradle`, `node`, and `python`.
- `platform` selects build/deployment platforms such as `windows`, `linux`, `android`, `apple`, `ios`, `macos`, `tvos`, `docker`, and `cloudflare`.

Rulesets target the default branch and must not use bypass actors.

## Policy activation model

Workflow files in `Avkroken/.github` are passive configuration. Their presence does not apply CI policy to any repository.

Organization-level rulesets are the policy binding layer. A ruleset selects repositories through Custom Properties and requires the corresponding workflow from `Avkroken/.github`.

Custom Properties are the repository assignment layer. Adding or removing a property value from a repository adds or removes the matching organization ruleset without changing repository files.

The standard rollout order for a new CI policy is:

1. Add the central workflow file.
2. Verify the workflow independently.
3. Create the organization ruleset that requires that workflow and selects repositories by Custom Property.
4. Assign the matching Custom Property value to each repository that needs the policy.

Existing workflows do not need to be renamed, deleted, wrapped, or compatibility-migrated when a new policy is added. Old and new central workflows may coexist safely because only active organization rulesets select and enforce them.

When retiring a policy, reverse the binding before deleting implementation:

1. Remove the matching Custom Property value from affected repositories.
2. Remove or disable the organization ruleset when no repositories need it.
3. Delete the central workflow only when it is no longer referenced.

## Workflow layers

Required workflows used by organization rulesets live in `.github/workflows/required-*.yml` when a thin policy entrypoint is needed. They contain supported ruleset triggers and select the repository profile.

Reusable implementation workflows live separately in `.github/workflows/` and are invoked by required entrypoints.

Required workflows that are executed by an organization ruleset against another repository must call reusable workflows through a fully qualified repository reference pinned to an immutable commit SHA, for example `Avkroken/.github/.github/workflows/swift.yml@<commit-sha>`. Relative reusable-workflow references such as `./.github/workflows/swift.yml` are not valid for this cross-repository ruleset execution model because they resolve in the target repository context. Mutable refs such as `@main` are also prohibited by CodeQL; when a reusable implementation changes, update the required-entrypoint pin in the same reviewed change.

A workflow that already contains supported ruleset triggers and repository-profile selection may be referenced directly by an organization ruleset without an additional `required-*.yml` wrapper.

Multiple required entrypoints and reusable workflows may coexist. A workflow becomes relevant to a repository only when an active organization ruleset selects that repository.

## Repository triage automation

Review routing and assignee routing are separate concerns.

`CODEOWNERS` remains the native ownership and reviewer-routing map. In `Avkroken/.github`, the current catch-all owner is `@blixten85`; this auto-assignment change does not modify `CODEOWNERS`.

`.github/workflows/reusable-auto-assign.yml` is the central assignee implementation. It receives an issue or pull request number, uses the caller repository's `GITHUB_TOKEN`, and calls GitHub's issue-assignee API with only `issues: write`. It does not use a PAT, GitHub App installation token, or third-party Action.

`.github/workflows/auto-assign.yml` is the repository-local caller for `Avkroken/.github`. It triggers when issues or pull requests are opened or reopened and calls the reusable implementation. Pull requests use `pull_request_target`; the workflow does not check out or execute pull-request code.

The special `.github` repository does not automatically propagate executable workflow files to every organization repository. To enable the same policy in another repository, that repository needs a thin caller workflow with `issues: write` that calls:

```yaml
uses: Avkroken/.github/.github/workflows/reusable-auto-assign.yml@960eec40fe1d6e5be88da27f7b6b75adff64f4fb
```

Cross-repository callers must pin the reusable workflow to a full immutable commit SHA. Mutable refs such as `@main` are not permitted because CodeQL flags them as an unpinned reusable workflow. When the central implementation changes, validate the new central commit first and then update caller SHAs through normal repository PRs.

`Avkroken/.github` uses its local reusable workflow path. Other repositories activate auto-assignment through their repo-local caller workflow.

## Publik projektdokumentation

Publik, versionsstyrd projektdokumentation har två separata presentationsvägar med samma canonical källor i repositoryt.

Konventionen är:

- `README.md` är en kort ingång med syfte, primära länkar och utvecklarstart.
- `docs/` är canonical source för den utförliga publika projektdokumentationen när ett repository har separat dokumentation.
- `docs/project-context.md` innehåller repositoryts aktuella tekniska kontext när projektet är tillräckligt komplext för att behöva ett sådant dokument.
- `avkroken.denied.se` är organisationens gemensamma dokumentationsnav och behöver inte GitHub Pages för att visa ett repository.
- Portalens `/api/docs` upptäcker automatiskt alla publika, oarkiverade repositories i organisationen. Den inventerar Markdown under `docs/` rekursivt och använder repositoryts README som fallback/översikt när den finns.
- Portalens `/api/docs/content` får endast hämta en fil som redan annonserats i den publika dokumentationskatalogen. Detta är en säkerhetsgräns så att ett eventuellt GitHub-token i Worker-miljön inte kan användas för att exponera privata repositories eller godtyckliga paths.
- Dokumentationsnavet renderar Markdown i portalens eget tema med repositoryflikar och dokumentflikar. Nya publika repositories och nya Markdown-filer blir därmed upptäckbara utan en manuell portalregistry.
- GitHub Pages är en valfri separat publiceringsyta för repositories som också behöver en fristående dokumentations-URL.
- `.github/workflows/pages-docs.yml` i `Avkroken/.github` är den centrala reusable implementationen för Jekyll-baserad Pages-publicering.
- Ett repository som använder Pages aktiverar publiceringen med en tunn caller-workflow som anropar den centrala workflowen och begränsar tokenbehörigheter till `contents: read`, `pages: write` och `id-token: write`.
- Pages ska använda GitHub Actions som publishing source. Ingen `gh-pages`-gren behövs.
- Projektets standardadress för Pages är organisationens project-site, till exempel `https://avkroken.github.io/<repository>/`. En separat custom domain får inte ersätta en befintlig produktionsdomän för applikationen av bekvämlighet.
- Allt innehåll som visas i dokumentationsnavet eller publiceras med Pages ska betraktas som publikt och får inte innehålla secrets, tokens, privata runbooks eller annan konfidentiell information.

Portalens dokumentationsnav aktiverar inte Pages och ändrar inga repositoryinställningar. Den centrala Pages-workflowen bygger endast dokumentation från en caller som uttryckligen använder den. Pages är inte en ruleset-policy.

## Stack CI

The reusable stack implementations are:

- `swift.yml` — SwiftPM build and test.
- `rust.yml` — Rust workspace build and test.
- `dotnet.yml` — .NET tests and optional Windows application build.
- `gradle.yml` — Gradle build and optional dependency submission.

The matching ruleset entrypoints are:

- `required-swift.yml`
- `required-rust.yml`
- `required-dotnet.yml`
- `required-gradle.yml`

Each entrypoint contains the current repository-specific profile and fails closed when a selected repository has no configured profile.

The Gradle reusable workflow declares a dependency-submission job with `contents: write`. Therefore `required-gradle.yml` must expose that permission ceiling to the reusable workflow even though ruleset PR/merge-group execution passes `dependency_submission: false`. The actual Gradle build job remains explicitly scoped to `contents: read`.

Node and Python are already direct ruleset workflows rather than reusable-only implementations:

- `node.yml` is selected by `main-node` through `ci_stack = node`.
- `python.yml` is selected by `main-python` through `ci_stack = python`.

## Platform CI

For Xcode-based application builds:

- `required-apple.yml` provides the generic Apple-family policy entrypoint.
- `apple.yml` contains the generic combined Apple reusable workflow.
- `required-ios.yml` provides the iOS-specific policy entrypoint.
- `required-macos.yml` provides the macOS-specific policy entrypoint.
- `required-tvos.yml` provides the tvOS-specific policy entrypoint.
- `xcode.yml` contains the shared platform-specific Xcode/XcodeGen build implementation.

Docker and Cloudflare are already direct ruleset workflows:

- `docker.yml` is selected by `main-docker` through `platform = docker`.
- `cloudflare.yml` is selected by `main-cloudflare` through `platform = cloudflare`.

The required platform workflows fail closed when a selected repository has no configured CI profile.

## Bastion profiles

Bastion currently uses these stack profiles:

- Swift: package path `.`, runners `ubuntu-latest` and `macos-latest`.
- Rust: working directory `LinuxApp` with GTK/libadwaita/VTE/GtkSourceView system packages.
- .NET: tests in `WindowsApp/Bastion.Core.Tests`, Windows application `WindowsApp/WindowsApp.csproj`, .NET 10, and OpenSSH test dependencies.
- Gradle: working directory `Android`, Java 17, project `:app`, and runtime-classpath dependency configuration.

Bastion uses these Xcode schemes:

- iOS: `Bastion`, destination `generic/platform=iOS Simulator`
- macOS: `Bastion-macOS`, destination `platform=macOS`
- tvOS: `Bastion-tvOS`, destination `generic/platform=tvOS Simulator`

Bastion generates its Xcode project through `App/generate-project.sh`. That script is part of the dependency-version path used by the Apple application build and must remain the generation entrypoint unless the dependency architecture is intentionally changed.

Bastion currently has `ci_stack = gradle, dotnet, rust, swift` and `platform = windows, linux, android, apple`. Platform-specific iOS/macOS/tvOS rulesets apply only after the corresponding values are assigned to its `platform` Custom Property.

## Ruleset mapping

The target organization-level stack mappings are:

- `main-swift` -> repository property `ci_stack = swift` -> `.github/workflows/required-swift.yml`
- `main-rust` -> repository property `ci_stack = rust` -> `.github/workflows/required-rust.yml`
- `main-dotnet` -> repository property `ci_stack = dotnet` -> `.github/workflows/required-dotnet.yml`
- `main-gradle` -> repository property `ci_stack = gradle` -> `.github/workflows/required-gradle.yml`
- `main-node` -> repository property `ci_stack = node` -> `.github/workflows/node.yml`
- `main-python` -> repository property `ci_stack = python` -> `.github/workflows/python.yml`

The organization-level platform mappings are:

- `main-ios` -> repository property `platform = ios` -> `.github/workflows/required-ios.yml`
- `main-macos` -> repository property `platform = macos` -> `.github/workflows/required-macos.yml`
- `main-tvos` -> repository property `platform = tvos` -> `.github/workflows/required-tvos.yml`
- `main-docker` -> repository property `platform = docker` -> `.github/workflows/docker.yml`
- `main-cloudflare` -> repository property `platform = cloudflare` -> `.github/workflows/cloudflare.yml`

A generic `main-apple` ruleset may independently target `platform = apple` and `.github/workflows/required-apple.yml` if an aggregated Apple-family policy is wanted. Its existence is independent of the platform-specific rulesets.
