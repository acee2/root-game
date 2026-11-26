import Foundation
import CoreGraphics

/// Tutti i contenuti del gioco. Per aggiungere livelli basta modificare questo file.
enum Livelli {

    /// Posizione dei nodi sulla mappa di rete (0...1).
    static let posizioni: [String: CGPoint] = [
        "10.0.0.5": CGPoint(x: 0.18, y: 0.78),
        "10.0.4.1": CGPoint(x: 0.42, y: 0.52),
        "10.0.4.12": CGPoint(x: 0.22, y: 0.24),
        "10.0.4.20": CGPoint(x: 0.72, y: 0.36),
        "77.12.0.3": CGPoint(x: 0.82, y: 0.10),
    ]

    static let programmiNegozio: [Programma] = [
        Programma(nome: "ftpbounce", descrizione: "Apre la porta 21 (FTP)", prezzo: 150),
        Programma(nome: "webworm", descrizione: "Apre la porta 80 (HTTP)", prezzo: 300),
        Programma(nome: "smtpoverflow", descrizione: "Apre la porta 25 (SMTP)", prezzo: 500),
        Programma(nome: "tracekill", descrizione: "Raddoppia il tempo prima del tracciamento", prezzo: 400),
    ]

    static let server: [Server] = [
        Server(ip: "10.0.0.5", nome: "Sandbox di Ghost", porte: [
            Porta(numero: 22, servizio: "SSH", programma: "sshcrack")
        ], porteRichieste: 1, tracciamento: 0, collegamenti: ["10.0.4.1"], file: [
            FileVirtuale(percorso: "/home/ghost/benvenuto.txt", contenuto: """
            Se stai leggendo questo, il messaggio a orologeria è partito.
            Io sono sparito. Tu sei il mio piano B.
            Comincia da Vortex Srl. Usa `scan` qui per trovare la loro rete.
            Ricorda: cancella sempre i /log prima di andartene.
            """),
            FileVirtuale(percorso: "/home/ghost/promemoria.txt", contenuto: "Comandi utili: probe, sshcrack 22, porthack, ls, cd, cat, download"),
            FileVirtuale(percorso: "/log/accessi.log", contenuto: "connessione da 127.0.0.1"),
        ]),
        Server(ip: "10.0.4.1", nome: "Vortex Srl - Gateway", porte: [
            Porta(numero: 22, servizio: "SSH", programma: "sshcrack")
        ], porteRichieste: 1, tracciamento: 0, collegamenti: ["10.0.4.12", "10.0.4.20"], file: [
            FileVirtuale(percorso: "/etc/motd", contenuto: "Benvenuto nella rete Vortex. Accesso riservato ai dipendenti."),
            FileVirtuale(percorso: "/log/accessi.log", contenuto: "nessuna anomalia"),
        ]),
        Server(ip: "10.0.4.12", nome: "Vortex Srl - Archivio", porte: [
            Porta(numero: 22, servizio: "SSH", programma: "sshcrack"),
            Porta(numero: 21, servizio: "FTP", programma: "ftpbounce"),
        ], porteRichieste: 2, tracciamento: 60, collegamenti: [], file: [
            FileVirtuale(percorso: "/docs/contratto.pdf", contenuto: "CONTRATTO RISERVATO\nVortex Srl fornirà a Helix AI l'accesso ai dati di 40 milioni di utenti."),
            FileVirtuale(percorso: "/docs/ferie.xls", contenuto: "Marco: agosto. Giulia: luglio."),
            FileVirtuale(percorso: "/log/accessi.log", contenuto: "backup notturno ok"),
        ]),
        Server(ip: "10.0.4.20", nome: "Vortex Srl - Posta", porte: [
            Porta(numero: 22, servizio: "SSH", programma: "sshcrack"),
            Porta(numero: 21, servizio: "FTP", programma: "ftpbounce"),
            Porta(numero: 80, servizio: "HTTP", programma: "webworm"),
        ], porteRichieste: 3, tracciamento: 45, collegamenti: ["77.12.0.3"], file: [
            FileVirtuale(percorso: "/home/marco/note.txt", contenuto: "Password del vault cambiata di nuovo... stavolta uso il nome del mio gatto: biscotto"),
            FileVirtuale(percorso: "/home/marco/vault/helix.enc", contenuto: """
            Helix AI: il progetto ORACOLO è operativo.
            Il nodo centrale è su 77.12.0.3. Ghost aveva ragione.
            """, password: "biscotto"),
            FileVirtuale(percorso: "/home/giulia/todo.txt", contenuto: "Ricordare a Marco di non scrivere le password nei file di testo."),
            FileVirtuale(percorso: "/log/accessi.log", contenuto: "login marco 08:12"),
        ]),
        Server(ip: "77.12.0.3", nome: "Helix AI - Nodo ORACOLO", porte: [
            Porta(numero: 22, servizio: "SSH", programma: "sshcrack"),
            Porta(numero: 21, servizio: "FTP", programma: "ftpbounce"),
            Porta(numero: 80, servizio: "HTTP", programma: "webworm"),
            Porta(numero: 25, servizio: "SMTP", programma: "smtpoverflow"),
        ], porteRichieste: 4, tracciamento: 40, collegamenti: [], file: [
            FileVirtuale(percorso: "/oracolo/nucleo.bin", contenuto: "01001111 01010010 01000001 01000011 01001111 01001100 01001111\nGhost è vivo. Lo trovi nel prossimo aggiornamento."),
            FileVirtuale(percorso: "/log/accessi.log", contenuto: "monitoraggio attivo"),
        ]),
    ]

    static let missioni: [Missione] = [
        Missione(id: 0, mittente: "ghost@anonimo", oggetto: "Se leggi, sono sparito",
                 testo: "Collegati alla mia sandbox 10.0.0.5 (`connect 10.0.0.5`), apri la porta SSH con `sshcrack 22`, poi `porthack`. Scarica benvenuto.txt e rispondi con `reply`.",
                 ipRivelati: ["10.0.0.5"], fileRichiesto: "benvenuto.txt", ricompensa: 200),
        Missione(id: 1, mittente: "ghost@anonimo", oggetto: "Il contratto",
                 testo: "Nell'archivio di Vortex c'è un contratto. Trovalo (`scan` dalla mia sandbox o dal loro gateway). Ti serve ftpbounce: compralo con `store` e `buy ftpbounce`. Attento: l'archivio ti traccia in 60 secondi.",
                 ipRivelati: [], fileRichiesto: "contratto.pdf", ricompensa: 450),
        Missione(id: 2, mittente: "ghost@anonimo", oggetto: "Il vault di Marco",
                 testo: "Marco della posta Vortex tiene un file cifrato. Le persone scrivono le password ovunque... Usa `decrypt <file> <password>` una volta scaricato.",
                 ipRivelati: [], fileRichiesto: "helix.enc", ricompensa: 700),
        Missione(id: 3, mittente: "ghost@anonimo", oggetto: "ORACOLO",
                 testo: "Ultimo passo. Entra nel nodo di Helix e prendi nucleo.bin. Ti servono 4 porte. Buona fortuna.",
                 ipRivelati: [], fileRichiesto: "nucleo.bin", ricompensa: 1500),
    ]
}
