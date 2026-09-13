# Access-inventering för `denied.se`

Den här filen beskriver vilken exponering varje host ska ha. Grundregeln är **privat tills motsatsen är uttryckligen beslutad**.

## Publika webbappar

Dessa hosts ska vara uttryckligen publika med policyn `Publik` på normal webb-/API-yta. Privilegierade delar ligger under `/admin` och använder policyn `Privat`.

| Host | Repo | Exponering |
| --- | --- | --- |
| `avkroken.denied.se` | `Avkroken/.github` | Publik portal, ingen adminyta |
| `klarsprak.denied.se` | `Avkroken/Klarsprak` | Publik, `/admin*` privat |
| `xn--klarsprk-g0a.denied.se` | `Avkroken/Klarsprak` | Alias till Klarspråk, samma modell |
| `dumpen.denied.se` | `Avkroken/Dumpen` | Publik startsida/protokollyta, `/admin*` privat |
| `politiker.denied.se` | `Avkroken/Politiker` | Publik, `/admin*` privat |
| `produkter.denied.se` | `Avkroken/Produkter` | Publik, `/admin*` privat |

`Publik` ska appliceras på dessa hosts uttryckligen. Wildcard `*.denied.se` ska inte användas för publik bypass.

Gamla privilegierade API-vägar får inte fortsätta fungera som alternativa säkerhetsgränser; de får endast redirecta till `/admin/...`.

## Helprivat app

`skvallerbyttan.denied.se` ska ha en hostspecifik Access-app med policyn `Privat`.

Workerns egen GitHub-inloggning behålls som defense in depth och för applikationsbehörighet.

Om tjänsten behöver publika webhook-, callback- eller health-paths ska de öppnas som smala, uttryckliga protokollundantag i stället för att göra hela hosten publik.

## Maskin-till-maskin

`motor.denied.se` i `Avkroken/Produkter` är en operatörsägd M2M-yta.

`/health` är avsiktligt publik. Övriga HTTP-endpoints kräver `X-API-Key`. Interna Worker-anrop ska använda Service Bindings där det är möjligt.

## Global Worker-standard

`All Workers` ska använda policyn `Privat` och fungera som fallback för befintliga och framtida Workers.

`workers.dev` och preview-URL:er ska vara avstängda när de inte behövs. Ingen ny Worker ska bli publik utan ett uttryckligt beslut och en hostspecifik öppning.

## Repon utan publik webbyta

`Avkroken/Bastion`, `Avkroken/Pastebinit` och `Avkroken/Docker-idempotent-update` har ingen motsvarande publik `*.denied.se`-webbapp i nuvarande repo-konfiguration och ska därför inte få något publikt Access-undantag.

## Kontroll vid framtida ändringar

En ny yta klassificeras som en av fyra saker:

- publik webb/API → explicit `Publik` host/path,
- privat mänsklig yta → `Privat`,
- M2M/protokollundantag → egen autentisering/capability och minsta möjliga publik path,
- ej behövd yta → exponera den inte alls.
