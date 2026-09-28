# Domain documentation

This repository uses a **single-context** domain-documentation convention.

## Read before domain-sensitive work

- `CONTEXT.md` at the repository root, when present.
- Relevant ADRs under `docs/adr/`, when present.
- The repository's existing README and technical documentation.

Absence of `CONTEXT.md` or `docs/adr/` is not an error. Do not create placeholder domain documentation merely to satisfy the convention; create or update it when domain terminology or architectural decisions actually need to be recorded.

## Vocabulary and decisions

Use established repository vocabulary consistently. If a change conflicts with an existing ADR, surface that conflict explicitly rather than silently overriding the recorded decision.
