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

`.github/workflows/issue-classification.md` är den centrala källan för GitHub Agentic Workflows-baserad metadata-only triage. Den kompilerade `.github/workflows/issue-classification.lock.yml` exponeras som en reusable `workflow_call` och anropas av tunna repo-local triggers på nya och återöppnade issues.

AI-triagen får endast lägga till **en temporär kombinationslabel** från en fast allowlist:

`classification:<difficulty>:<security>`

Exempel: `classification:medium:none`.

Den deterministiska metadata-workflowen översätter sedan den temporära labeln till exakt en kanonisk `difficulty:*` och exakt en kanonisk `security:*`, tar bort temporärlabeln och härleder därefter `agent:*` och `priority:*`. Befintliga kanoniska labels tar företräde över AI-output, så AI:n skriver aldrig över en manuell eller GitHub-native klassificering.

Labelskrivningen sker genom `gh-aw` safe outputs med `max: 1` och en uttrycklig allowlist. Agentdelen är read-only för repository/issue-data. Missing-tool, missing-data, incomplete-report, noop och workflow-failure får inte skapa fallback-issues. Workflowen får inte kommentera, assigna, skapa eller ändra branches/PR:er, starta coding agents, reviewa, mergea eller utföra remediation.

Workflowen använder organisationens Copilot-billing via `GITHUB_TOKEN`. Caller-jobbet måste uttryckligen ge `copilot-requests: write`; ingen separat `COPILOT_GITHUB_TOKEN` eller annan PAT ska skickas till reusable workflowen.

## Deterministisk metadata-routing

`.github/workflows/metadata-routing.yml` är en reusable workflow. Caller-repon skickar `item-kind` (`issue` eller `pull_request`) och `item-number`. Workflowen:

1. säkerställer de standardiserade labels som policyn använder,
2. lägger till `blixten85` som assignee,
3. validerar och normaliserar issueklassificeringen,
4. konverterar eventuell temporär `classification:*`-label,
5. härleder `agent:*` och `priority:*` deterministiskt.

Workflowen checkar inte ut eller exekverar kod från pull requests. `.github/workflows/metadata-events.yml` kopplar samma policy till issues och pull requests i detta repository. Övriga repositories använder tunna callers och refererar den centrala reusable workflowen med en full commit-SHA.

## Visibility och secrets

Repositoryt är publikt så att både publika och privata caller-repositories kan använda de centrala reusable workflowsen. Innehållet här ska därför alltid betraktas som offentligt.

Inga secrets, tokens, privata nycklar eller provider-credentials ska committas här.

## Gamnacken för GitHub Actions

Organisationsautomation som skapar GitHub App-installationstokens med **Gamnacken** använder två kanoniska värden i GitHub Actions:

- `GAMNACKEN_CLIENT_ID` — organisationens Actions-variable med GitHub Appens Client ID.
- `GAMNACKEN_PRIVATE_KEY` — organisationens Actions-secret med GitHub Appens PEM/private key.

Centrala reusable workflows läser Client ID från organisationens Actions-variable. Caller-repon mappar den privata nyckeln explicit till reusable-workflow-secreten `app-private-key`.

Dessa namn och värden hör till **GitHub Actions**. Externa runtimes, till exempel Cloudflare Workers, ärver inte GitHub Actions variables eller secrets och ska använda sina dokumenterade runtime-specifika bindings i stället för att anta att org-värdena finns där.

## Repository-policy

Metadata-only AI-triage är ett uttryckligt begränsat undantag från förbud mot AI-delegering. Det undantaget tillåter inte kodändringar, remediation, reviewautomation, branch-/PR-mutation eller deployment. Varje caller-repository måste dessutom tillåta metadataautomation i sin egen `AGENTS.md` och live-policy.
