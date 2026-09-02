# Avkroken GitHub policy

Det här repositoryt är den centrala källan för Avkrokens gemensamma GitHub-metadataautomation och organisationsgemensamma agentkonfiguration.

## Metadata policy

Alla nya issues och pull requests ska ha `blixten85` som mänsklig owner/assignee.

Issues routas först när de har exakt en svårighetsgrad och exakt en säkerhetsgrad:

| Classification | Derived routing |
| --- | --- |
| `difficulty:low` | `agent:copilot` |
| `difficulty:medium` | `agent:codex` |
| `difficulty:high` | `agent:claude` |
| `security:critical` | `priority:p0` |
| `security:high` | `priority:p1` |
| `security:medium` | `priority:p2` |
| `security:low` | `priority:p3` |
| `security:none` | `priority:p4` |

Om någon klassificeringsdimension saknas sätts `triage:pending`. Om flera labels inom samma dimension finns samtidigt sätts `triage:invalid`. I båda fallen tas eventuella härledda `agent:*`- och `priority:*`-labels bort så att routingen är fail-closed.

`agent:*` är routingmetadata. Den deterministiska workflowen startar inte Claude, Codex eller Copilot som coding agent.

## Automatisk issueklassificering

`.github/workflows/issue-classification.md` är källan för GitHub Agentic Workflows-baserad metadata-only triage. Den körs för nya och återöppnade issues och får bara klassificera genom att lägga till exakt:

- en `difficulty:*`-label, och
- en `security:*`-label.

Labelskrivningen sker genom `gh-aw` safe outputs med en uttrycklig allowlist. Agentdelen är read-only för repository/issue-data och använder GitHubs Copilot-request-behörighet; inga externa AI-provider-credentials ska användas. Workflowen får inte kommentera, assigna, skapa eller ändra branches/PR:er, starta coding agents, reviewa, mergea eller utföra remediation.

`.github/workflows/issue-classification.lock.yml` är den genererade körbara workflowen. Källan och lockfilen ska hållas synkroniserade och kompileras med officiella `github/gh-aw`.

## Deterministisk metadata-routing

`.github/workflows/metadata-routing.yml` är en reusable workflow. Caller-repon skickar `item-kind` (`issue` eller `pull_request`) och `item-number`. Workflowen:

1. säkerställer de standardiserade labels som policyn använder,
2. lägger till `blixten85` som assignee,
3. validerar issueklassificeringen,
4. härleder `agent:*` och `priority:*` deterministiskt.

Workflowen checkar inte ut eller exekverar kod från pull requests. `.github/workflows/metadata-events.yml` kopplar samma policy till issues och pull requests i detta repository. Övriga repositories använder tunna callers och refererar den centrala reusable workflowen med en full commit-SHA.

## Visibility och secrets

Repositoryt är publikt så att både publika och privata caller-repositories kan använda den centrala reusable workflowen. Innehållet här ska därför alltid betraktas som offentligt.

Inga secrets, tokens, privata nycklar eller provider-credentials ska committas här.

## Repository-policy

Metadata-only AI-triage är ett uttryckligt begränsat undantag från förbud mot AI-delegering. Det undantaget tillåter inte kodändringar, remediation, reviewautomation, branch-/PR-mutation eller deployment. Varje caller-repository måste dessutom tillåta metadataautomation i sin egen `AGENTS.md` och live-policy.
