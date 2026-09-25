# Avkroken/.github

Det här repositoryt är Avkrokens publika GitHub-organisationsyta.

Det innehåller sådant som är gemensamt på GitHub:

- organisationsprofil i `profile/README.md`,
- community health-filer,
- issue-/discussion-/pull request-mallar där GitHub kan ärva dem,
- implementationen för den automatiskt genererade dokumentationsspegeln.

## Dokumentationsspegel

`docs-portal/` och dess Pages-workflow får läsa publik dokumentation från Avkrokens repositories och Wikis och publicera en samlad läsvy.

Spegeln är **inte source of truth**.

Varje repository äger själv sin:

- README,
- `docs/`,
- Wiki,
- Issues,
- Discussions,
- tekniska current-state.

Ändringar görs därför alltid i ursprungsrepositoryt. Den centrala portalen ska visa canonical-länk och uppdateras automatiskt från källorna.

Applikationskod, repo-specifik engineering-current-state och privata driftuppgifter hör inte hemma här.
