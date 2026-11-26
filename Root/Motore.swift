import Foundation
import SwiftUI
import UIKit

struct Riga: Identifiable {
    enum Tipo { case normale, comando, errore, successo, sistema }
    let id = UUID()
    let testo: String
    let tipo: Tipo
}

@MainActor
final class Motore: ObservableObject {
    @Published var righe: [Riga] = []
    @Published var stato = StatoPartita()
    @Published var tempoRimasto: Int? = nil
    @Published var connessoA: Server? = nil
    @Published var cartella = "/"

    private var server: [String: Server] = [:]
    @Published private(set) var porteAperte: Set<Int> = []
    @Published private(set) var haAccesso = false
    private var timer: Timer?
    private(set) var cronologia: [String] = []

    private let chiaveSalvataggio = "root.salvataggio"

    init() {
        if let demo = ProcessInfo.processInfo.environment["ROOT_DEMO"] {
            ricostruisciServer()
            caricaDemo(demo)
            return
        }
        carica()
        ricostruisciServer()
        scrivi("ROOT OS v0.2 — terminale sicuro", .sistema)
        scrivi("Digita `help` per l'elenco dei comandi, `mail` per i messaggi.", .sistema)
        if stato.missioniCompletate.isEmpty && stato.ipConosciuti.isEmpty {
            consegnaMissione(0)
        }
    }

    var missioneAttuale: Missione? {
        Livelli.missioni.first { $0.id == stato.missioneCorrente }
    }

    // MARK: - Output

    func scrivi(_ t: String, _ tipo: Riga.Tipo = .normale) {
        righe.append(Riga(testo: t, tipo: tipo))
        switch tipo {
        case .errore: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .successo: UINotificationFeedbackGenerator().notificationOccurred(.success)
        default: break
        }
        if righe.count > 400 { righe.removeFirst(righe.count - 400) }
    }

    // MARK: - Esecuzione comandi

    func esegui(_ input: String) {
        let riga = input.trimmingCharacters(in: .whitespaces)
        guard !riga.isEmpty else { return }
        cronologia.append(riga)
        let prompt = connessoA.map { "\($0.ip):\(cartella)" } ?? "locale"
        scrivi("\(prompt)$ \(riga)", .comando)

        let parti = riga.split(separator: " ").map(String.init)
        let cmd = parti[0].lowercased()
        let arg = Array(parti.dropFirst())

        switch cmd {
        case "help": help()
        case "clear": righe.removeAll()
        case "mail": mail()
        case "reply": reply()
        case "status": status()
        case "store": store()
        case "buy": buy(arg.first)
        case "files": filesLocali()
        case "scan": scan()
        case "probe": probe()
        case "connect": connect(arg.first)
        case "disconnect", "dc", "exit": disconnect()
        case "porthack": porthack()
        case "ls": ls()
        case "cd": cd(arg.first)
        case "cat": cat(arg.first)
        case "download", "dl": download(arg.first)
        case "rm": rm(arg.first)
        case "decrypt": decrypt(arg.first, arg.dropFirst().first)
        case "sudo": scrivi("Bel tentativo. Qui il root lo devi guadagnare.", .errore)
        case "reset": resetPartita()
        default:
            if let porta = Livelli.server.flatMap(\.porte).first(where: { $0.programma == cmd }) {
                apriPorta(programma: cmd, argomento: arg.first, attesa: porta)
            } else {
                scrivi("Comando sconosciuto: \(cmd). Prova `help`.", .errore)
            }
        }
        salva()
    }

    // MARK: - Comandi locali

    private func help() {
        scrivi("""
        MAIL    mail, reply
        RETE    scan, probe, connect <ip>, disconnect
        ATTACCO sshcrack 22, ftpbounce 21, webworm 80, smtpoverflow 25, porthack
        SERVER  ls, cd <cartella>, cat <file>, download <file>, rm <file|*>
        LOCALE  files, decrypt <file> <password>, status, store, buy <programma>
        ALTRO   clear, reset
        """)
    }

    private func mail() {
        guard let m = missioneAttuale else {
            scrivi("Nessun nuovo messaggio. Hai completato tutte le missioni disponibili.", .successo)
            return
        }
        scrivi("Da: \(m.mittente)\nOggetto: \(m.oggetto)\n\n\(m.testo)\n\nObiettivo: consegna \(m.fileRichiesto)")
    }

    private func reply() {
        guard let m = missioneAttuale else { scrivi("Non c'è nessuna missione a cui rispondere.", .errore); return }
        guard let f = stato.fileScaricati.first(where: { nomeFile($0.percorso) == m.fileRichiesto }) else {
            scrivi("Non hai ancora scaricato \(m.fileRichiesto).", .errore); return
        }
        if f.password != nil { scrivi("\(m.fileRichiesto) è ancora cifrato. Usa decrypt.", .errore); return }
        stato.crediti += m.ricompensa
        stato.missioniCompletate.insert(m.id)
        scrivi("Missione completata! +\(m.ricompensa) crediti.", .successo)
        consegnaMissione(m.id + 1)
    }

    private func consegnaMissione(_ id: Int) {
        stato.missioneCorrente = id
        guard let m = Livelli.missioni.first(where: { $0.id == id }) else {
            scrivi("Fine della demo. Ghost ti contatterà presto...", .sistema); return
        }
        stato.ipConosciuti.formUnion(m.ipRivelati)
        scrivi("📨 Nuova mail: \"\(m.oggetto)\" — digita `mail`.", .sistema)
    }

    private func status() {
        scrivi("Crediti: \(stato.crediti)\nProgrammi: \(stato.programmi.sorted().joined(separator: ", "))\nIP noti: \(stato.ipConosciuti.sorted().joined(separator: ", "))")
    }

    private func store() {
        scrivi("NEGOZIO — crediti: \(stato.crediti)")
        for p in Livelli.programmiNegozio {
            let posseduto = stato.programmi.contains(p.nome) ? " [posseduto]" : ""
            scrivi("  \(p.nome) — \(p.prezzo)cr — \(p.descrizione)\(posseduto)")
        }
    }

    private func buy(_ nome: String?) {
        guard let nome, let p = Livelli.programmiNegozio.first(where: { $0.nome == nome.lowercased() }) else {
            scrivi("Uso: buy <programma>. Vedi `store`.", .errore); return
        }
        if stato.programmi.contains(p.nome) { scrivi("Lo possiedi già.", .errore); return }
        if stato.crediti < p.prezzo { scrivi("Crediti insufficienti.", .errore); return }
        stato.crediti -= p.prezzo
        stato.programmi.insert(p.nome)
        scrivi("Installato \(p.nome).", .successo)
    }

    private func filesLocali() {
        if stato.fileScaricati.isEmpty { scrivi("Nessun file scaricato."); return }
        for f in stato.fileScaricati {
            scrivi("  \(nomeFile(f.percorso))\(f.password != nil ? "  [cifrato]" : "")")
        }
    }

    private func decrypt(_ nome: String?, _ pw: String?) {
        guard let nome, let pw else { scrivi("Uso: decrypt <file> <password>", .errore); return }
        guard let i = stato.fileScaricati.firstIndex(where: { nomeFile($0.percorso) == nome }) else {
            scrivi("File locale non trovato. Scaricalo prima.", .errore); return
        }
        guard let giusta = stato.fileScaricati[i].password else { scrivi("Il file non è cifrato."); return }
        if pw == giusta {
            stato.fileScaricati[i].password = nil
            scrivi("Decifrato!\n\(stato.fileScaricati[i].contenuto)", .successo)
        } else {
            scrivi("Password errata.", .errore)
        }
    }

    // MARK: - Rete

    private func scan() {
        guard let s = connessoA else {
            scrivi("Scansione locale: nessun nodo vicino. Collegati a un server e scansiona da lì.", .errore); return
        }
        guard haAccesso else { scrivi("Serve accesso root per scansionare da questo nodo.", .errore); return }
        if s.collegamenti.isEmpty { scrivi("Nessun nodo collegato."); return }
        for ip in s.collegamenti {
            let nuovo = stato.ipConosciuti.insert(ip).inserted
            scrivi("  trovato \(ip)  \(server[ip]?.nome ?? "?")\(nuovo ? "  [NUOVO]" : "")", nuovo ? .successo : .normale)
        }
    }

    private func probe() {
        guard let s = connessoA else { scrivi("Non sei connesso.", .errore); return }
        scrivi("\(s.nome) (\(s.ip))\nPorte richieste per porthack: \(s.porteRichieste)")
        for p in s.porte {
            scrivi("  \(p.numero) \(p.servizio)  \(porteAperte.contains(p.numero) ? "APERTA" : "chiusa")  → \(p.programma)")
        }
        scrivi(s.tracciamento > 0 ? "⚠️ Tracciamento attivo: \(tempoTraccia(s))s" : "Nessun tracciamento.")
    }

    private func tempoTraccia(_ s: Server) -> Int {
        stato.programmi.contains("tracekill") ? s.tracciamento * 2 : s.tracciamento
    }

    private func connect(_ ip: String?) {
        guard let ip else { scrivi("Uso: connect <ip>", .errore); return }
        guard stato.ipConosciuti.contains(ip), let s = server[ip] else {
            scrivi("Host \(ip) irraggiungibile.", .errore); return
        }
        if connessoA != nil { disconnect() }
        connessoA = s
        cartella = "/"
        porteAperte = []
        haAccesso = false
        scrivi("Connesso a \(s.nome). Usa `probe`.", .successo)
        aggiungiLog("connessione sospetta da IP sconosciuto")
        if s.tracciamento > 0 { avviaTraccia(tempoTraccia(s)) }
    }

    func disconnect() {
        guard let s = connessoA else { scrivi("Non sei connesso.", .errore); return }
        fermaTraccia()
        let logRimasti = (server[s.ip]?.file ?? []).contains { $0.percorso.hasPrefix("/log/") && $0.contenuto.contains("sospetta") }
        if s.tracciamento > 0 && logRimasti {
            let multa = min(stato.crediti, 100)
            stato.crediti -= multa
            scrivi("Hai lasciato tracce nei log! Ti hanno identificato: -\(multa) crediti.", .errore)
        }
        connessoA = nil
        haAccesso = false
        cartella = "/"
        scrivi("Disconnesso.")
    }

    private func apriPorta(programma: String, argomento: String?, attesa: Porta) {
        guard stato.programmi.contains(programma) else { scrivi("Non possiedi \(programma). Vedi `store`.", .errore); return }
        guard let s = connessoA else { scrivi("Non sei connesso.", .errore); return }
        guard let num = argomento.flatMap(Int.init),
              let porta = s.porte.first(where: { $0.numero == num }) else {
            scrivi("Uso: \(programma) \(attesa.numero)", .errore); return
        }
        guard porta.programma == programma else { scrivi("\(programma) non funziona sulla porta \(num).", .errore); return }
        porteAperte.insert(num)
        scrivi("[\(programma)] porta \(num) \(porta.servizio) aperta.", .successo)
    }

    private func porthack() {
        guard let s = connessoA else { scrivi("Non sei connesso.", .errore); return }
        if haAccesso { scrivi("Hai già accesso root."); return }
        if porteAperte.count < s.porteRichieste {
            scrivi("Servono \(s.porteRichieste) porte aperte, ne hai \(porteAperte.count).", .errore); return
        }
        haAccesso = true
        scrivi("PORTHACK riuscito. Accesso root ottenuto.", .successo)
    }

    // MARK: - File system

    private func fileServer() -> [FileVirtuale]? {
        guard let s = connessoA else { scrivi("Non sei connesso.", .errore); return nil }
        guard haAccesso else { scrivi("Accesso negato. Usa porthack.", .errore); return nil }
        return server[s.ip]?.file ?? []
    }

    private func percorsoAssoluto(_ p: String) -> String {
        if p.hasPrefix("/") { return p }
        if p == ".." {
            var c = cartella.split(separator: "/").map(String.init); _ = c.popLast()
            return "/" + c.joined(separator: "/")
        }
        return (cartella == "/" ? "/" : cartella + "/") + p
    }

    private func ls() {
        guard let files = fileServer() else { return }
        let base = cartella == "/" ? "/" : cartella + "/"
        var voci = Set<String>()
        for f in files where f.percorso.hasPrefix(base) {
            let resto = f.percorso.dropFirst(base.count)
            if let slash = resto.firstIndex(of: "/") { voci.insert(String(resto[..<slash]) + "/") }
            else { voci.insert(String(resto)) }
        }
        scrivi(voci.isEmpty ? "(vuota)" : voci.sorted().map { "  " + $0 }.joined(separator: "\n"))
    }

    private func cd(_ dest: String?) {
        guard let files = fileServer() else { return }
        guard let dest else { cartella = "/"; return }
        let p = percorsoAssoluto(dest.hasSuffix("/") ? String(dest.dropLast()) : dest)
        if p == "/" || files.contains(where: { $0.percorso.hasPrefix(p + "/") }) { cartella = p.isEmpty ? "/" : p }
        else { scrivi("Cartella non trovata: \(dest)", .errore) }
    }

    private func cat(_ nome: String?) {
        guard let files = fileServer(), let nome else { if nome == nil { scrivi("Uso: cat <file>", .errore) }; return }
        guard let f = files.first(where: { $0.percorso == percorsoAssoluto(nome) }) else { scrivi("File non trovato.", .errore); return }
        scrivi(f.password != nil ? "▓▓▒░ contenuto cifrato ░▒▓▓" : f.contenuto)
    }

    private func download(_ nome: String?) {
        guard let files = fileServer(), let nome else { if nome == nil { scrivi("Uso: download <file>", .errore) }; return }
        guard let f = files.first(where: { $0.percorso == percorsoAssoluto(nome) }) else { scrivi("File non trovato.", .errore); return }
        stato.fileScaricati.removeAll { nomeFile($0.percorso) == nomeFile(f.percorso) }
        stato.fileScaricati.append(f)
        scrivi("Scaricato \(nomeFile(f.percorso)).", .successo)
        aggiungiLog("file \(nomeFile(f.percorso)) copiato da sessione sospetta")
    }

    private func rm(_ nome: String?) {
        guard fileServer() != nil, let s = connessoA, let nome else { if nome == nil { scrivi("Uso: rm <file> oppure rm *", .errore) }; return }
        var files = server[s.ip]?.file ?? []
        let prima = files.count
        if nome == "*" {
            let base = cartella == "/" ? "/" : cartella + "/"
            files.removeAll { $0.percorso.hasPrefix(base) && !$0.percorso.dropFirst(base.count).contains("/") }
        } else {
            let p = percorsoAssoluto(nome)
            files.removeAll { $0.percorso == p }
        }
        server[s.ip]?.file = files
        stato.serverModificati[s.ip] = files
        scrivi(files.count < prima ? "Eliminati \(prima - files.count) file." : "Nessun file eliminato.", files.count < prima ? .successo : .errore)
    }

    private func aggiungiLog(_ testo: String) {
        guard let s = connessoA, var srv = server[s.ip] else { return }
        let n = srv.file.filter { $0.percorso.hasPrefix("/log/") }.count
        srv.file.append(FileVirtuale(percorso: "/log/evento\(n).log", contenuto: testo))
        server[s.ip] = srv
    }

    // MARK: - Tracciamento

    private func avviaTraccia(_ secondi: Int) {
        tempoRimasto = secondi
        scrivi("⚠️ TRACCIAMENTO AVVIATO: \(secondi) secondi.", .errore)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let t = tempoRimasto else { return }
        if t <= 1 {
            fermaTraccia()
            let multa = stato.crediti / 2
            stato.crediti -= multa
            scrivi("🚨 SEI STATO TRACCIATO! Connessione interrotta. -\(multa) crediti.", .errore)
            if let ip = connessoA?.ip, let originale = Livelli.server.first(where: { $0.ip == ip }) {
                server[ip] = originale
                stato.serverModificati[ip] = nil
            }
            connessoA = nil; haAccesso = false; cartella = "/"
            salva()
        } else {
            tempoRimasto = t - 1
        }
    }

    private func fermaTraccia() {
        timer?.invalidate(); timer = nil; tempoRimasto = nil
    }

    // MARK: - Salvataggio

    private func ricostruisciServer() {
        server = Dictionary(uniqueKeysWithValues: Livelli.server.map { ($0.ip, $0) })
        for (ip, files) in stato.serverModificati { server[ip]?.file = files }
    }

    /// Server per la mappa di rete.
    func info(_ ip: String) -> Server? { server[ip] }

    /// Mail ricevute finora (la più recente per prima).
    var mailRicevute: [Missione] {
        Livelli.missioni.filter { $0.id <= stato.missioneCorrente }.reversed()
    }

    private var modalitaDemo = false

    /// Stato preimpostato per gli screenshot automatici.
    private func caricaDemo(_ schermata: String) {
        modalitaDemo = true
        stato.crediti = 650
        stato.programmi.formUnion(["ftpbounce", "webworm"])
        stato.ipConosciuti = ["10.0.0.5", "10.0.4.1", "10.0.4.12", "10.0.4.20"]
        stato.missioneCorrente = 2
        stato.missioniCompletate = [0, 1]
        scrivi("ROOT OS v0.2 — terminale sicuro", .sistema)
        for c in ["connect 10.0.4.20", "probe", "sshcrack 22", "ftpbounce 21", "webworm 80",
                  "porthack", "cd home/marco", "ls", "cat note.txt"] { esegui(c) }
        tempoRimasto = 32
    }

    func salva() {
        guard !modalitaDemo else { return }
        if let dati = try? JSONEncoder().encode(stato) { UserDefaults.standard.set(dati, forKey: chiaveSalvataggio) }
    }

    private func carica() {
        if let dati = UserDefaults.standard.data(forKey: chiaveSalvataggio),
           let s = try? JSONDecoder().decode(StatoPartita.self, from: dati) { stato = s }
    }

    private func resetPartita() {
        fermaTraccia()
        stato = StatoPartita()
        connessoA = nil; haAccesso = false; cartella = "/"
        ricostruisciServer()
        righe.removeAll()
        scrivi("Partita azzerata.", .sistema)
        consegnaMissione(0)
    }

    private func nomeFile(_ p: String) -> String { String(p.split(separator: "/").last ?? "") }
}
