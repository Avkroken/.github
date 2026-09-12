# Access-standard för Avkrokens webbappar

Den här standarden gör Cloudflare Access-regler återanvändbara mellan appar på `*.denied.se`.

Aktuell klassificering av domäner och undantag finns i [Access-inventeringen](./access-inventory.md).

## Publik yta

Normala webb- och API-vägar är publika om appen är avsedd att vara publik.

```text
/                       publik
/kontakt                publik
/api/...                publik om endpointen uttryckligen är publik
```

En app som i sin helhet ska vara privat är ett undantag och ska använda en egen Access-app/policy, normalt `Konto`.

## Admin

All operatörs- och administrationsfunktionalitet ska exponeras under:

```text
/admin
/admin/*
/admin/api/*
```

Cloudflare Access skyddar detta med den återanvändbara policyn `Admin`.

Privilegierade API-endpoints får inte ha en alternativ fungerande väg utanför `/admin`. Under migrering ska en gammal adminväg redirecta till den kanoniska `/admin/...`-vägen i stället för att fortsätta hantera anropet direkt.

Appens egen sessions-, roll- eller tokenkontroll ska behållas som defense in depth även när Cloudflare Access ligger framför.

## Kritisk

Operationer som behöver den hårdaste Access-nivån reserveras för:

```text
/admin/critical
/admin/critical/*
/admin/critical/api/*
```

Cloudflare Access skyddar detta med policyn `Kritisk`.

Flytta inte en åtgärd hit utan att även kontrollera användarflödet. Interaktiv MFA måste kunna slutföras innan ett API-anrop görs; ett dolt `fetch()`-anrop ska inte vara den första kontakten med en ny kritisk Access-session.

## URL-fragment är inte en säkerhetsgräns

En route som `/#admin` skyddas inte av en Access-regel för `/admin`, eftersom delen efter `#` aldrig skickas till servern eller Cloudflare.

Admin-SPA:er ska därför använda `/admin` som faktisk pathname. Ett fragment kan fortfarande användas internt efter den skyddade pathen, exempelvis:

```text
/admin#accounts
```

## Undantag

Publika capability-/engångstoken-endpoints, OAuth-callbacks, webhooks och maskin-till-maskin-endpoints får ligga utanför `/admin` när protokollet kräver det. Undantaget ska vara avsiktligt och endpointen ska ha egen autentisering, begränsad behörighet och lämplig rate limiting.

## Migreringsmönster

För befintliga appar används i första hand ett tunt routinglager:

1. Den nya externa `/admin/...`-vägen skrivs internt om till befintlig handler.
2. Den gamla privilegierade vägen redirectas med `307` eller `308` till `/admin/...`.
3. Befintlig affärslogik och app-auth lämnas oförändrad.
4. Tester verifierar både canonical route, legacy-redirect och publika undantag.

Detta gör att den generiska Access-konfigurationen kan börja skydda appen utan en riskfylld omskrivning av kärnlogiken.
