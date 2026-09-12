# Avkroken/.github

Central organization repository for Avkroken.

## Structure

- `profile/README.md` — public GitHub organization profile
- `portal/` — Cloudflare Worker for `https://avkroken.denied.se`
- `CODEOWNERS` — ownership/review mapping
- `workflow-templates/` — reserved for shared GitHub Actions templates

## Portal opt-in

The portal reads only **public** repositories in the GitHub organization.

To show a repository on `avkroken.denied.se`:

1. Set the repository **Website** field to the public website URL.
2. Add the repository topic `avkroken-portal`.
3. Use the repository description as the portal card description.

Optional category topics:

- `portal-project`
- `portal-tool`
- `portal-docs`
- `portal-service`
- `portal-experiment`

Optional accent topics:

- `portal-cyan`
- `portal-blue`
- `portal-violet`
- `portal-magenta`
- `portal-pink`

Remove `avkroken-portal` to hide the site again. No portal redeploy is required.
The Worker caches GitHub metadata for 5 minutes.

## Privacy boundary

The Worker calls GitHub's public organization-repository endpoint with `type=public`.
Private Cloudflare Tunnel/Access hostnames are not stored in this repository and are
not discovered by the portal.

## Cloudflare

Use `portal/` as the Worker project root.

The Worker serves:
- `/`
- `/avkroken-login-logo.svg`
- `/access-denied.svg`
- `/access-denied/`
- `/api/sites`

No D1, KV or R2 is required.

An optional `GITHUB_TOKEN` Worker secret can be added later for authenticated GitHub
API requests. It is not required for public repository metadata.
