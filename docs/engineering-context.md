# Engineering context

## Central GitHub architecture

`Avkroken/.github` is the organization-level source of truth for reusable CI implementation and ruleset-required workflow entrypoints.

Repositories are selected into organization rulesets through GitHub Custom Properties. The current conventions are:

- `ci_stack` selects build/runtime stacks such as `swift`, `rust`, `dotnet`, and `gradle`.
- `platform` selects build/deployment platforms such as `windows`, `linux`, `android`, `apple`, `ios`, `macos`, and `tvos`.

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

Required workflows used by organization rulesets live in `.github/workflows/required-*.yml`. They contain supported ruleset triggers and select the repository profile.

Reusable implementation workflows live separately in `.github/workflows/` and are invoked by required entrypoints.

Multiple required entrypoints and reusable workflows may coexist. A workflow becomes relevant to a repository only when an active organization ruleset selects that repository.

For Xcode-based application builds:

- `required-apple.yml` provides the generic Apple-family policy entrypoint.
- `apple.yml` contains the generic combined Apple reusable workflow.
- `required-ios.yml` provides the iOS-specific policy entrypoint.
- `required-macos.yml` provides the macOS-specific policy entrypoint.
- `required-tvos.yml` provides the tvOS-specific policy entrypoint.
- `xcode.yml` contains the shared platform-specific Xcode/XcodeGen build implementation.

The required platform workflows fail closed when a selected repository has no configured CI profile.

## Bastion platform profile

Bastion uses these platform-specific Xcode schemes:

- iOS: `Bastion`, destination `generic/platform=iOS Simulator`
- macOS: `Bastion-macOS`, destination `platform=macOS`
- tvOS: `Bastion-tvOS`, destination `generic/platform=tvOS Simulator`

Bastion generates its Xcode project through `App/generate-project.sh`. That script is part of the dependency-version path used by the Apple application build and must remain the generation entrypoint unless the dependency architecture is intentionally changed.

Bastion currently has `platform = apple` and will receive the platform-specific rulesets only after `ios`, `macos`, and `tvos` are assigned to its `platform` Custom Property.

## Ruleset mapping

The organization-level platform mappings are:

- `main-ios` -> repository property `platform = ios` -> `.github/workflows/required-ios.yml`
- `main-macos` -> repository property `platform = macos` -> `.github/workflows/required-macos.yml`
- `main-tvos` -> repository property `platform = tvos` -> `.github/workflows/required-tvos.yml`

A generic `main-apple` ruleset may independently target `platform = apple` and `.github/workflows/required-apple.yml` if an aggregated Apple-family policy is wanted. Its existence is independent of the platform-specific rulesets.
