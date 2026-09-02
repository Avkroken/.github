---
description: >-
  Metadata-only AI triage for new and reopened issues. Applies exactly one
  difficulty label and one security label; all other routing is deterministic.
on:
  issues:
    types: [opened, reopened]
permissions:
  contents: read
  issues: read
  copilot-requests: write
safe-outputs:
  add-labels:
    allowed:
      - "difficulty:low"
      - "difficulty:medium"
      - "difficulty:high"
      - "security:critical"
      - "security:high"
      - "security:medium"
      - "security:low"
      - "security:none"
    max: 2
    target: triggering
    create-if-missing: true
    issues: true
    pull-requests: false
---

# Avkroken metadata-only issue triage

Analyze only the triggering issue title and body, plus read-only repository context when needed to understand scope.

Apply exactly two labels to the triggering issue:

1. Exactly one difficulty label:
   - `difficulty:low`: localized, well-scoped change with low uncertainty and little cross-component coordination.
   - `difficulty:medium`: multiple files/components, meaningful investigation, integration work, or moderate uncertainty.
   - `difficulty:high`: architectural or cross-system work, substantial uncertainty, migration/concurrency/security complexity, or a large coordinated change.

2. Exactly one security label:
   - `security:critical`: credible immediate risk of severe compromise, broad unauthorized access, secret exposure with major blast radius, or similarly urgent security impact.
   - `security:high`: credible significant security impact requiring prompt remediation but not meeting critical criteria.
   - `security:medium`: bounded or conditional security impact with meaningful risk.
   - `security:low`: minor defense-in-depth/security hardening issue with limited practical impact.
   - `security:none`: no credible security impact is described or implied by the issue.

Security classification is about security impact, not general product urgency. Do not use a security label to represent outage severity, feature importance, or business priority. Do not invent a security impact that is not supported by the issue or repository context; use `security:none` when there is no credible security dimension.

Do not add any other labels. Do not comment, assign users or agents, create or update branches or pull requests, start an agent session, edit issue text, close issues, perform review, merge anything, or modify repository content. Do not propose or perform remediation. The deterministic metadata workflow handles owner assignment, `agent:*`, `priority:*`, and triage state after these two classification labels are present.
