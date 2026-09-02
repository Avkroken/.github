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

Om någon av klassificeringsdimensionerna saknas sätts `triage:pending`. Om flera labels inom samma dimension finns samtidigt sätts `triage:invalid`. I båda fallen tas eventuella härledda `agent:*`- och `priority:*`-labels bort för att routingen ska vara fail-closed.

`agent:*` är routingmetadata. Den centrala workflowen startar inte Claude eller Codex direkt. Automatisk tredjeparts-agentdispatch ska endast läggas till när GitHub har en dokumenterad native/API-väg som kan användas med minsta nödvändiga behörighet och utan externa provider-credentials. Copilot-assignment hanteras separat eftersom GitHubs nuvarande automatiseringsstöd skiljer sig från tredjepartsagenterna.

## Central workflow

`.github/workflows/metadata-routing.yml` är en reusable workflow. Caller-repon skickar `item-kind` (`issue` eller `pull_request`) och `item-number`. Workflowen:

1. säkerställer de standardiserade labels som policyn använder,
2. lägger till `blixten85` som assignee,
3. validerar issueklassificeringen,
4. härleder `agent:*` och `priority:*` deterministiskt.

Workflowen checkar inte ut eller exekverar kod från pull requests.

## Visibility

Repositoryt är för närvarande privat. Organisationsgemensamma custom agents i `/agents` kan fortfarande användas inom organisationen när de läggs till. Publika Avkroken-repositories kan däremot inte anropa en reusable workflow från ett privat repository. För att använda den centrala workflowen från publika repositories måste detta repository göras publikt, eller workflowkällan flyttas till ett annat publikt repository.

Inga secrets, tokens, privata nycklar eller provider-credentials ska committas här.
