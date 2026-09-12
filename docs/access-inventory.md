# Access-inventering för `denied.se`

Den här filen kompletterar [Access-standarden](./access-path-standard.md) med aktuell klassificering av Avkrokens webb- och Worker-ytor. Den beskriver vilken URL-modell koden ska följa; den ersätter inte kontroll av faktisk Cloudflare-konfiguration.

## Publika appar med standardiserad adminyta

Följande appar använder den gemensamma modellen där normal yta är publik och privilegierad trafik ligger under `/admin`:

| Host | Repo | Adminmodell |
| --- | --- | --- |
| `klarsprak.denied.se` | `Avkroken/Klarsprak` | `/admin`, `/admin/*`, `/admin/api/*` |
| `xn--klarsprk-g0a.denied.se` | `Avkroken/Klarsprak` | samma Worker och adminmodell |
| `dumpen.denied.se` | `Avkroken/Dumpen` | `/admin`, `/admin/*`, `/admin/api/*` |
| `politiker.denied.se` | `Avkroken/Politiker` | `/admin`, `/admin/*`, `/admin/api/*` |
| `produkter.denied.se` | `Avkroken/Produkter` | `/admin`, `/admin/*`, `/admin/api/*` |

Gamla privilegierade API-vägar ska inte fortsätta fungera som alternativa säkerhetsgränser. Under migrering får de bara redirecta till den kanoniska `/admin/...`-vägen.

## Publik portal

`avkroken.denied.se` är den publika organisationsportalen. Den har ingen adminyta i portal-Workern.

`/access-denied/` är avsedd som gemensam publik felsida för Access-avslag och får därför inte göras beroende av en `/admin`-session eller annan Access-inloggning som kan skapa en redirect-loop.

## Helprivat undantag

`skvallerbyttan.denied.se` är klassificerad som en helprivat dashboard och behöver därför inte delas upp i publik `/` plus `/admin`. Workern kräver autentiserad användare för dashboard och API, med undantag för explicita inloggnings-/callbackvägar och hälsokontroller.

Detta är ett avsiktligt undantag enligt standarden. Om tjänsten senare får en publik yta ska privilegierade funktioner först flyttas till `/admin` innan den publika delen öppnas.

## Maskin-till-maskin-undantag

`motor.denied.se` i `Avkroken/Produkter` är en operatörsägd maskin-till-maskin-yta. Den ska inte flyttas till `/admin` bara för att den är privilegierad, eftersom den inte är ett interaktivt admin-gränssnitt.

Den publika hälsokontrollen är avsiktlig. Övriga HTTP-endpoints ska fortsätta kräva egen autentisering (`X-API-Key`) och begränsad funktionalitet. Interna Worker-anrop bör använda Service Bindings där det är möjligt.

## Repon utan webb-/custom-domain-yta

`Avkroken/Bastion`, `Avkroken/Pastebinit` och `Avkroken/Docker-idempotent-update` ingår inte i den här URL-migreringen eftersom de inte exponerar någon motsvarande `*.denied.se`-webbapp i nuvarande repo-konfiguration.

## Kontroll vid framtida ändringar

När en ny webbapp eller ny privilegierad endpoint läggs till ska den klassificeras här samtidigt som routingen byggs:

- publik funktion → normal route eller `/api/...`
- interaktiv adminfunktion → `/admin/...` eller `/admin/api/...`
- kritisk interaktiv funktion → `/admin/critical/...`
- helprivat app → dokumenterat undantag
- OAuth, webhook, capability-token eller M2M → dokumenterat protokollundantag med egen autentisering
