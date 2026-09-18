# Engineering context

## Central GitHub architecture

`Avkroken/.github` is the organization-level source of truth for reusable CI implementation and ruleset-required workflow entrypoints.

Repositories are selected into organization rulesets through GitHub Custom Properties. The current conventions are:

- `ci_stack` selects build/runtime stacks such as `swift`, `rust`, `dotnet`, and `gradle`.
- `platform` selects concrete build/deployment platforms such as `windows`, `linux`, `android`, `ios`, `macos`, and `tvos`.

Rulesets target the default branch and must not use bypass actors.

## Workflow layers

Required workflows used by organization rulesets live in `.github/workflows/required-*.yml`. They contain supported ruleset triggers and select the repository profile.

Reusable implementation workflows live separately in `.github/workflows/` and are invoked by required entrypoints.

For Xcode-based application builds:

- `required-ios.yml` selects repositories with the iOS platform policy.
- `required-macos.yml` selects repositories with the macOS platform policy.
- `required-tvos.yml` selects repositories with the tvOS platform policy.
- `xcode.yml` contains the shared Xcode/XcodeGen build implementation.

The required platform workflows fail closed when a selected repository has no configured CI profile.

## Bastion platform profile

Bastion uses these platform-specific Xcode schemes:

- iOS: `Bastion`, destination `generic/platform=iOS Simulator`
- macOS: `Bastion-macOS`, destination `platform=macOS`
- tvOS: `Bastion-tvOS`, destination `generic/platform=tvOS Simulator`

Bastion generates its Xcode project through `App/generate-project.sh`. That script is part of the dependency-version path used by the Apple application build and must remain the generation entrypoint unless the dependency architecture is intentionally changed.

## Ruleset mapping

The target organization rulesets for Apple-family platforms are:

- `main-ios` -> repository property `platform = ios` -> `.github/workflows/required-ios.yml`
- `main-macos` -> repository property `platform = macos` -> `.github/workflows/required-macos.yml`
- `main-tvos` -> repository property `platform = tvos` -> `.github/workflows/required-tvos.yml`

The previous generic `platform = apple` / `main-apple` model is not the target architecture.
