# Avkroken GitHub policy

Det här repositoryt är den centrala källan för Avkrokens gemensamma GitHub-metadataautomation och organisationsgemensamma agentkonfiguration.


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

Issueklassificeringen är deterministisk metadataautomation och är inte ett AI-delegeringsundantag. Den får endast läsa issue-metadata och skriva de labels som krävs för klassificering/routing; den får inte ändra kod, skapa remediation, reviewa, mergea eller deploya.
