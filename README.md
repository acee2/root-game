# Root

Gioco iOS in stile hacking/terminale (ispirato a Hacknet). Tutto offline, gira solo sul telefono.

## Build
Ogni push su `main` avvia GitHub Actions: l'IPA (non firmata) finisce in **Releases** e negli artefatti.
Installala con SideStore o dentro LiveContainer.

## Aggiungere livelli
Modifica `Root/Livelli.swift`: server, file, missioni e programmi del negozio.

## Comandi
`help` mostra tutto. Percorso tipico: `mail` → `connect <ip>` → `probe` → `sshcrack 22` → `porthack` → `ls`/`cd`/`cat` → `download` → `rm *` in /log → `disconnect` → `reply`.
