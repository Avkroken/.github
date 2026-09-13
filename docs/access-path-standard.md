# Access-standard för Avkrokens webbappar

Grundprincipen är **neka som standard**. Ingenting ska bli publikt bara för att det råkar ligga på en Worker eller under `*.denied.se`.

## Två Access-policys

### Privat

Används där en människa måste vara autentiserad innan ytan får nås.

```text
Decision: Allow
Include: Cloudflare account member
```

Samma policy återanvänds för privata appar, adminytor och den globala Worker-fallbacken. Applikationen avgör därefter roller och behörigheter.

### Publik

Används endast där Internet uttryckligen ska få komma åt ytan.

```text
Decision: Bypass
Include: Everyone
```

`Publik` får **inte** appliceras på `*.denied.se` som wildcard. Varje publik host ska öppnas uttryckligen.

## Global fallback

`All Workers` ska använda policyn `Privat`.

Det gör befintliga och framtida Workers privata tills en mer specifik host eller path uttryckligen öppnas.

`workers.dev` och preview-URL:er ska vara avstängda i repo-konfiguration när de inte behövs.

## Publika webbappar

En publik webbapp öppnas per host, till exempel:

```text
politiker.denied.se  -> Publik
produkter.denied.se  -> Publik
```

Privilegierade delar av en publik app ligger under en faktisk pathname:

```text
/admin
/admin/*
/admin/api/*
```

Dessa paths använder policyn `Privat`.

Det finns ingen separat Access-nivå för "kritisk". Viktiga operationer skyddas av appens egen behörighetskontroll, färsk autentisering, bekräftelse och loggning där det behövs.

Privilegierade API-endpoints får inte ha en alternativ fungerande väg utanför `/admin`. En äldre väg får endast redirecta till den kanoniska `/admin/...`-vägen.

## Helprivata appar

En app som inte har någon publik funktion ska få en hostspecifik Access-app med policyn `Privat`.

Exempel:

```text
skvallerbyttan.denied.se -> Privat
```

## Protokollundantag

OAuth-callbacks, webhooks, capability-/engångstoken-endpoints och maskin-till-maskin-endpoints får vara publikt routbara när protokollet kräver det.

De ska då ha egen autentisering eller capability, minsta möjliga behörighet och lämplig rate limiting. Ett protokollundantag är inte skäl att göra hela hosten publik.

## URL-fragment

En route som `/#admin` är aldrig en säkerhetsgräns eftersom delen efter `#` inte skickas till Cloudflare eller servern.

Admin-SPA:er ska använda `/admin` som faktisk pathname.

## Regel för nya Access-policys

Skapa inte en ny policy om den inte ändrar minst en av följande saker:

1. vilken grupp som får tillgång,
2. autentiseringsmekanismen,
3. exponeringstypen på ett fundamentalt sätt.

Om inget av detta ändras ska en befintlig policy återanvändas.
