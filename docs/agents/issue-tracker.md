# Issue tracker: GitHub

GitHub Issues is the canonical issue and specification tracker for this repository.

## Working convention

- Use the authenticated GitHub connector when available; otherwise use `gh` from an authenticated clone.
- Read the full issue, labels, comments, linked pull requests, and dependencies before acting.
- Create one issue per coherent problem or deliverable; keep acceptance criteria and blockers in the issue body.
- Use native GitHub issue dependencies and sub-issues when they are available instead of encoding hidden dependency state elsewhere.
- Keep implementation decisions in version-controlled repository documentation when they outlive the issue.
- Pull requests are implementation/review artifacts, not a replacement issue tracker.

## Common operations

- Create: `gh issue create --title "..." --body-file <file>`
- Read: `gh issue view <number> --comments`
- List: `gh issue list --state open`
- Comment: `gh issue comment <number> --body-file <file>`
- Close: `gh issue close <number> --comment "..."`

When a skill says to publish or fetch a ticket, use this repository's GitHub Issues tracker.
