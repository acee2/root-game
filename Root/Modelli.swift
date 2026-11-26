import Foundation

/// Una porta di un server: per aprirla serve il programma indicato.
struct Porta: Codable, Hashable {
    let numero: Int
    let servizio: String   // es. "SSH"
    let programma: String  // es. "sshcrack"
}

/// Un file sul file system virtuale di un server.
struct FileVirtuale: Codable, Hashable {
    var percorso: String          // es. "/home/marco/note.txt"
    var contenuto: String
    var password: String? = nil   // se impostata il file è cifrato (.enc)
}

/// Un server della rete di gioco.
struct Server: Codable, Identifiable {
    var id: String { ip }
    let ip: String
    let nome: String
    let porte: [Porta]
    let porteRichieste: Int       // porte da aprire prima di `porthack`
    let tracciamento: Int         // secondi prima di essere tracciati (0 = nessuno)
    let collegamenti: [String]    // IP scoperti con `scan` da qui
    var file: [FileVirtuale]
}

/// Una missione ricevuta per mail.
struct Missione: Codable, Identifiable {
    let id: Int
    let mittente: String
    let oggetto: String
    let testo: String
    let ipRivelati: [String]
    let fileRichiesto: String     // nome del file da consegnare
    let ricompensa: Int
}

/// Un programma acquistabile.
struct Programma: Codable, Identifiable {
    var id: String { nome }
    let nome: String
    let descrizione: String
    let prezzo: Int
}

/// Stato salvato della partita.
struct StatoPartita: Codable {
    var crediti = 0
    var programmi: Set<String> = ["sshcrack", "porthack", "scan", "probe"]
    var ipConosciuti: Set<String> = []
    var fileScaricati: [FileVirtuale] = []
    var missioneCorrente = 0
    var missioniCompletate: Set<Int> = []
    var serverModificati: [String: [FileVirtuale]] = [:]  // file cancellati/modificati
}
