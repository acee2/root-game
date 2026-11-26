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
    @Published var avviso: Avviso? = nil

    struct Avviso: Equatable {
        let id = UUID()
        let titolo: String
        let testo: String
        let icona: String
        let tipo: Riga.Tipo
    }

    func avvisa(_ titolo: String, _ testo: String, _ icona: String, _ tipo: Riga.Tipo) {
        let a = Avviso(titolo: titolo, testo: testo, icona: icona, tipo: tipo)
        avviso = a
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if avviso?.id == a.id { avviso = nil }
        }
    }

    func completaTutorial() { stato.tutorialVisto = true; salva() }

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
        scrivi("ROOT OS v0.3 — terminale sicuro", .sistema)
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
        avvisa("MISSIONE COMPLETATA", "+\(m.ricompensa) crediti", "checkmark.seal.fill", .successo)
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
        avvisa("PROGRAMMA INSTALLATO", p.nome, "cpu", .successo)
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
            avvisa("FILE DECIFRATO", "Ora puoi consegnarlo nella Posta", "lock.open.fill", .successo)
        } else {
            scrivi("Password errata.", .errore)
            avvisa("PASSWORD ERRATA", "Cerca un indizio nei file del server", "xmark.octagon.fill", .errore)
        }
    }

    // MARK: - Rete

    private func scan() {
        guard let s = connessoA else {
            scrivi("Scansione locale: nessun nodo vicino. Collegati a un server e scansiona da lì.", .errore); return
        }
        guard haAccesso else { scrivi("Serve accesso root per scansionare da questo nodo.", .errore); return }
        if s.collegamenti.isEmpty { scrivi("Nessun nodo collegato."); avvisa("NESSUN SERVER", "Da qui non si raggiunge altro", "dot.radiowaves.left.and.right", .normale); return }
        let nuovi = s.collegamenti.filter { !stato.ipConosciuti.contains($0) }.count
        avvisa(nuovi > 0 ? "\(nuovi) NUOVI SERVER" : "NIENTE DI NUOVO", nuovi > 0 ? "Li trovi sulla mappa" : "Conosci già tutti i server vicini", "dot.radiowaves.left.and.right", nuovi > 0 ? .successo : .normale)
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
        avvisa("ACCESSO ROOT", "Ora puoi esplorare i file del server", "lock.open.fill", .successo)
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
        avvisa("FILE SCARICATO", nomeFile(f.percorso), "arrow.down.doc.fill", .successo)
        aggiungiLog("file \(nomeFile(f.percorso)) copiato da sessione sospetta")
    }

    private func rm(_ nome: String?) {
        guard fileServer() != nil, let s = connessoA, let nome else { if nome == nil { scrivi("Uso: rm <file> oppure rm *", .errore) }; return }
        var files = server[s.ip]?.file ?? []
        let prima = files.count
        if nome == "*" || nome.hasSuffix("/*") {
            let dir = nome == "*" ? cartella : percorsoAssoluto(String(nome.dropLast(2)))
            let base = dir == "/" ? "/" : dir + "/"
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
        avvisa("TI STANNO RINTRACCIANDO", "Hai \(secondi) secondi: fai in fretta e cancella i log", "dot.radiowaves.left.and.right", .errore)
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
            avvisa("SEI STATO TRACCIATO", "-\(multa) crediti. Riprova più veloce!", "exclamationmark.triangle.fill", .errore)
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

    // MARK: - Guida per il giocatore

    enum Azione: Equatable {
        case connetti(String), porta(Int), compra(String), porthack, scarica(String)
        case cancellaLog, disconnetti, rispondi, decifra(String), scansiona, nessuna
    }

    struct Guida { let testo: String; let azione: Azione }

    struct Voce: Identifiable {
        var id: String { percorso }
        let nome: String
        let percorso: String
        let cartella: Bool
        let file: FileVirtuale?
    }

    /// Contenuto della cartella corrente del server (solo con accesso root).
    func vociCartella() -> [Voce] {
        guard let s = connessoA, haAccesso, let files = server[s.ip]?.file else { return [] }
        let base = cartella == "/" ? "/" : cartella + "/"
        var cartelle = Set<String>()
        var voci: [Voce] = []
        for f in files where f.percorso.hasPrefix(base) {
            let resto = f.percorso.dropFirst(base.count)
            if let slash = resto.firstIndex(of: "/") {
                let nome = String(resto[..<slash])
                if cartelle.insert(nome).inserted {
                    voci.append(Voce(nome: nome, percorso: base + nome, cartella: true, file: nil))
                }
            } else {
                voci.append(Voce(nome: String(resto), percorso: f.percorso, cartella: false, file: f))
            }
        }
        return voci.sorted { ($0.cartella ? 0 : 1, $0.nome) < ($1.cartella ? 0 : 1, $1.nome) }
    }

    var logPresenti: Bool {
        guard let s = connessoA else { return false }
        return (server[s.ip]?.file ?? []).contains { $0.percorso.hasPrefix("/log/") && $0.contenuto.contains("sospetta") }
    }

    /// Nodo noto da cui scansionare per avvicinarsi a `obiettivo`.
    private func nodoDaScansionare(verso obiettivo: String) -> String? {
        for noto in stato.ipConosciuti.sorted() {
            var coda = server[noto]?.collegamenti ?? []
            var visti = Set<String>()
            while !coda.isEmpty {
                let ip = coda.removeFirst()
                if ip == obiettivo { return noto }
                guard !stato.ipConosciuti.contains(ip), visti.insert(ip).inserted else { continue }
                coda += server[ip]?.collegamenti ?? []
            }
        }
        return nil
    }

    struct Passo: Identifiable {
        let id: Int
        let testo: String
        let fatto: Bool
    }

    /// Lista dei passi della missione corrente, con quelli già completati.
    var passiMissione: [Passo] {
        guard let m = missioneAttuale else { return [] }
        let t = m.serverObiettivo
        let srv = server[t]
        let nome = srv?.nome.components(separatedBy: " - ").last ?? t
        let file = stato.fileScaricati.first { nomeFile($0.percorso) == m.fileRichiesto }
        let haFile = file != nil
        let suObiettivo = connessoA?.ip == t
        var lista: [(String, Bool)] = []
        if !m.ipRivelati.contains(t) {
            lista.append(("Trova il server \(nome) con Scansiona", stato.ipConosciuti.contains(t)))
        }
        lista.append(("Connettiti a \(nome)", haFile || suObiettivo))
        let richieste = srv?.porteRichieste ?? 1
        let aperte = suObiettivo ? porteAperte.count : 0
        lista.append(("Apri le porte (\(min(aperte, richieste))/\(richieste))", haFile || (suObiettivo && (aperte >= richieste || haAccesso))))
        lista.append(("Ottieni l'accesso root", haFile || (suObiettivo && haAccesso)))
        lista.append(("Scarica \(m.fileRichiesto)", haFile))
        if (srv?.tracciamento ?? 0) > 0 {
            lista.append(("Cancella i log prima di uscire", haFile && !(suObiettivo && logPresenti)))
        }
        if Livelli.server.first(where: { $0.ip == t })?.file.contains(where: { nomeFile($0.percorso) == m.fileRichiesto && $0.password != nil }) == true {
            lista.append(("Decifra il file con la password", haFile && file?.password == nil))
        }
        lista.append(("Consegnalo nella Posta", false))
        return lista.enumerated().map { Passo(id: $0.offset, testo: $0.element.0, fatto: $0.element.1) }
    }

    /// Esegue direttamente l'azione consigliata. Ritorna la scheda da mostrare, se serve.
    func eseguiGuida() {
        switch guida.azione {
        case .connetti(let ip): esegui("connect \(ip)")
        case .porta(let n):
            if let p = connessoA?.porte.first(where: { $0.numero == n }) { esegui("\(p.programma) \(n)") }
        case .porthack: esegui("porthack")
        case .scarica(let p): esegui("download \(p)")
        case .cancellaLog: esegui("rm /log/*")
        case .scansiona: esegui("scan")
        case .rispondi: esegui("reply")
        case .compra(let n): esegui("buy \(n)")
        case .disconnetti: esegui("disconnect")
        case .decifra, .nessuna: break
        }
    }

    var guida: Guida {
        guard let m = missioneAttuale else { return Guida(testo: "Demo completata! Nuove missioni in arrivo.", azione: .nessuna) }
        let tracciato = (connessoA?.tracciamento ?? 0) > 0
        if let f = stato.fileScaricati.first(where: { nomeFile($0.percorso) == m.fileRichiesto }) {
            if connessoA != nil && tracciato && logPresenti { return Guida(testo: "Cancella i log prima di uscire!", azione: .cancellaLog) }
            if f.password != nil { return Guida(testo: "Decifra \(m.fileRichiesto) nella sezione File (cerca la password nel server)", azione: .decifra(m.fileRichiesto)) }
            return Guida(testo: "Rispondi alla mail di \(m.mittente) nella Posta", azione: .rispondi)
        }
        let destinazione: String
        let scopo: String
        if stato.ipConosciuti.contains(m.serverObiettivo) {
            destinazione = m.serverObiettivo; scopo = "obiettivo"
        } else if let n = nodoDaScansionare(verso: m.serverObiettivo) {
            destinazione = n; scopo = "scansione"
        } else {
            return Guida(testo: "Leggi la mail nella Posta", azione: .nessuna)
        }
        guard let s = connessoA, s.ip == destinazione else {
            if connessoA != nil && tracciato && logPresenti { return Guida(testo: "Cancella i log prima di cambiare server", azione: .cancellaLog) }
            let nome = server[destinazione]?.nome ?? destinazione
            return Guida(testo: "Connettiti a \(nome) (\(destinazione))", azione: .connetti(destinazione))
        }
        if !haAccesso {
            if porteAperte.count >= s.porteRichieste { return Guida(testo: "Lancia PORTHACK per ottenere l'accesso", azione: .porthack) }
            if let p = s.porte.first(where: { !porteAperte.contains($0.numero) && stato.programmi.contains($0.programma) }) {
                return Guida(testo: "Apri la porta \(p.numero) \(p.servizio) con \(p.programma)", azione: .porta(p.numero))
            }
            if let p = s.porte.first(where: { !stato.programmi.contains($0.programma) }) {
                return Guida(testo: "Ti manca \(p.programma): compralo nello Shop", azione: .compra(p.programma))
            }
        }
        if scopo == "scansione" { return Guida(testo: "Scansiona la rete per trovare nuovi server", azione: .scansiona) }
        if let f = server[s.ip]?.file.first(where: { nomeFile($0.percorso) == m.fileRichiesto }) {
            return Guida(testo: "Trova e scarica \(m.fileRichiesto)", azione: .scarica(f.percorso))
        }
        return Guida(testo: "Esplora il server", azione: .nessuna)
    }

    /// Stato preimpostato per gli screenshot automatici.
    private func caricaDemo(_ schermata: String) {
        modalitaDemo = true
        stato.tutorialVisto = schermata == "tutorial" ? nil : true
        stato.crediti = 650
        stato.programmi.formUnion(["ftpbounce", "webworm"])
        stato.ipConosciuti = ["10.0.0.5", "10.0.4.1", "10.0.4.12", "10.0.4.20"]
        stato.missioneCorrente = 2
        stato.missioniCompletate = [0, 1]
        scrivi("ROOT OS v0.3 — terminale sicuro", .sistema)
        let comandi: [String]
        switch schermata {
        case "mappa", "posta", "shop": comandi = ["mail"]
        case "porte": comandi = ["connect 10.0.4.20", "probe", "sshcrack 22"]
        case "file":
            comandi = ["connect 10.0.4.20", "sshcrack 22", "ftpbounce 21", "webworm 80", "porthack",
                       "download /home/marco/vault/helix.enc", "download /home/marco/note.txt", "rm /log/*", "disconnect"]
        default:
            comandi = ["connect 10.0.4.20", "probe", "sshcrack 22", "ftpbounce 21", "webworm 80",
                       "porthack", "cd home/marco", "ls", "cat note.txt"]
        }
        for c in comandi { esegui(c) }
        if connessoA != nil { tempoRimasto = 32 }
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
