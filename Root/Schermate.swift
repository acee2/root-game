import SwiftUI

// MARK: - Terminale

struct TerminaleView: View {
    @EnvironmentObject var motore: Motore
    var autoFocus = true
    @State private var input = ""
    @State private var indiceCronologia: Int? = nil
    @State private var cursore = true
    @FocusState private var focus: Bool

    private var rapidi: [String] {
        if motore.connessoA == nil { return ["mail", "connect ", "status", "files", "store", "help"] }
        if !motore.haAccesso {
            let porte = motore.connessoA?.porte.filter { !motore.porteAperte.contains($0.numero) }
                .map { "\($0.programma) \($0.numero)" } ?? []
            return ["probe"] + porte + ["porthack", "disconnect"]
        }
        return ["ls", "cd ..", "cd /log", "rm *", "scan", "download ", "disconnect"]
    }

    private var prompt: String {
        guard let s = motore.connessoA else { return "ghost@locale:~$" }
        return "\(motore.haAccesso ? "root" : "guest")@\(s.ip):\(motore.cartella)$"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(motore.righe) { r in
                            RigaView(riga: r).id(r.id)
                        }
                        Color.clear.frame(height: 4).id("fondo")
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                }
                .onChange(of: motore.righe.count) { _ in
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("fondo", anchor: .bottom) }
                }
                .onAppear { proxy.scrollTo("fondo", anchor: .bottom) }
                .onTapGesture { focus = true }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button("↑") { cronologia(-1) }
                    Button("↓") { cronologia(1) }
                    ForEach(rapidi, id: \.self) { c in
                        Button(c.trimmingCharacters(in: .whitespaces)) {
                            if c.hasSuffix(" ") { input = c; focus = true } else { esegui(c) }
                        }
                    }
                }
                .buttonStyle(TastoTerminale())
                .padding(.horizontal, 10).padding(.vertical, 7)
            }
            .background(Tema.pannello)
            .overlay(alignment: .top) { Rectangle().fill(Tema.verde.opacity(0.2)).frame(height: 1) }

            HStack(spacing: 8) {
                Text(prompt)
                    .font(Tema.mono(12, .bold))
                    .foregroundColor(motore.haAccesso ? Tema.ciano : Tema.verde)
                    .lineLimit(1)
                    .layoutPriority(1)
                ZStack(alignment: .leading) {
                    if input.isEmpty && !focus {
                        Text(cursore ? "█" : " ").foregroundColor(Tema.verde)
                    }
                    TextField("", text: $input)
                        .focused($focus)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .foregroundColor(.white)
                        .tint(Tema.verde)
                        .onSubmit { esegui(input); focus = true }
                }
                .font(Tema.mono(14))
                Button("TAB") { completa() }.buttonStyle(TastoTerminale(colore: Tema.ambra))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.black)
        }
        .onAppear { if autoFocus { focus = true } }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 530_000_000)
                cursore.toggle()
            }
        }
    }

    private func esegui(_ c: String) {
        motore.esegui(c)
        input = ""
        indiceCronologia = nil
    }

    private func cronologia(_ passo: Int) {
        let h = motore.cronologia
        guard !h.isEmpty else { return }
        let i = min(max((indiceCronologia ?? h.count) + passo, 0), h.count - 1)
        indiceCronologia = i
        input = h[i]
    }

    private func completa() {
        let comandi = ["help", "mail", "reply", "status", "store", "buy", "files", "scan", "probe", "connect",
                       "disconnect", "porthack", "ls", "cd", "cat", "download", "rm", "decrypt", "clear",
                       "sshcrack", "ftpbounce", "webworm", "smtpoverflow"]
        let parti = input.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        if parti.count <= 1 {
            if let m = comandi.first(where: { $0.hasPrefix(input.lowercased()) }) { input = m + " " }
        } else if parti[0] == "connect", let ip = motore.stato.ipConosciuti.sorted().first(where: { $0.hasPrefix(parti[1]) }) {
            input = "connect " + ip
        } else if parti[0] == "buy", let p = Livelli.programmiNegozio.first(where: { $0.nome.hasPrefix(parti[1]) }) {
            input = "buy " + p.nome
        }
    }
}

struct RigaView: View {
    let riga: Riga

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if riga.tipo == .errore { Text("✖").foregroundColor(Tema.rosso) }
            if riga.tipo == .successo { Text("✔").foregroundColor(Tema.ciano) }
            if riga.tipo == .sistema { Text("»").foregroundColor(Tema.ambra) }
            Text(riga.testo)
                .foregroundColor(colore)
                .fontWeight(riga.tipo == .comando ? .bold : .regular)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .font(Tema.mono(12.5))
        .bagliore(colore, raggio: riga.tipo == .normale ? 2 : 3)
        .padding(.top, riga.tipo == .comando ? 8 : 0)
    }

    private var colore: Color {
        switch riga.tipo {
        case .normale: return Tema.verde.opacity(0.85)
        case .comando: return .white
        case .errore: return Tema.rosso
        case .successo: return Tema.ciano
        case .sistema: return Tema.ambra
        }
    }
}

// MARK: - Mappa di rete

struct ReteView: View {
    @EnvironmentObject var motore: Motore
    @Binding var scheda: Scheda
    @State private var selezionato: String? = nil

    private var noti: [String] { motore.stato.ipConosciuti.sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TitoloSezione(testo: "MAPPA DI RETE")
            GeometryReader { g in
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Canvas { ctx, size in
                            // griglia
                            var x: CGFloat = 0
                            while x < size.width {
                                ctx.fill(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)), with: .color(Tema.verde.opacity(0.07)))
                                x += 24
                            }
                            var y: CGFloat = 0
                            while y < size.height {
                                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(Tema.verde.opacity(0.07)))
                                y += 24
                            }
                            // collegamenti
                            for ip in noti {
                                guard let s = motore.info(ip), let a = punto(ip, size) else { continue }
                                for dest in s.collegamenti where noti.contains(dest) {
                                    guard let b = punto(dest, size) else { continue }
                                    var p = Path(); p.move(to: a); p.addLine(to: b)
                                    ctx.stroke(p, with: .color(Tema.verde.opacity(0.35)),
                                               style: StrokeStyle(lineWidth: 1, dash: [4, 4], dashPhase: CGFloat(-t * 12)))
                                    // pacchetto che viaggia
                                    let f = CGFloat((t * 0.4).truncatingRemainder(dividingBy: 1))
                                    let q = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
                                    ctx.fill(Path(ellipseIn: CGRect(x: q.x - 2, y: q.y - 2, width: 4, height: 4)), with: .color(Tema.verde))
                                }
                            }
                        }
                        ForEach(noti, id: \.self) { ip in
                            if let p = punto(ip, g.size) {
                                NodoView(ip: ip, server: motore.info(ip), connesso: motore.connessoA?.ip == ip,
                                         root: motore.connessoA?.ip == ip && motore.haAccesso,
                                         selezionato: selezionato == ip, tempo: t)
                                    .position(p)
                                    .onTapGesture {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        selezionato = ip
                                    }
                            }
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tema.verde.opacity(0.3)))

            if let ip = selezionato ?? motore.connessoA?.ip, let s = motore.info(ip) {
                DettaglioNodo(server: s, aperte: motore.connessoA?.ip == ip ? motore.porteAperte : []) {
                    if motore.connessoA?.ip != ip { motore.esegui("connect \(ip)") }
                    scheda = .terminale
                }
            } else {
                Text("Tocca un nodo per i dettagli. Scopri nuovi nodi con `scan`.")
                    .font(Tema.mono(12)).foregroundColor(Tema.verde.opacity(0.6))
                    .pannello()
            }
        }
        .padding(14)
    }

    private func punto(_ ip: String, _ size: CGSize) -> CGPoint? {
        guard let p = Livelli.posizioni[ip] else { return nil }
        return CGPoint(x: 30 + p.x * (size.width - 60), y: 30 + p.y * (size.height - 60))
    }
}

struct NodoView: View {
    let ip: String
    let server: Server?
    let connesso: Bool
    let root: Bool
    let selezionato: Bool
    let tempo: Double

    private var colore: Color {
        if root { return Tema.ciano }
        if connesso { return Tema.verde }
        if (server?.tracciamento ?? 0) > 0 { return Tema.ambra }
        return Tema.verde.opacity(0.7)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if connesso {
                    Circle().stroke(colore.opacity(0.5), lineWidth: 1)
                        .frame(width: 44 + CGFloat(sin(tempo * 3) * 6), height: 44 + CGFloat(sin(tempo * 3) * 6))
                }
                Rectangle()
                    .stroke(colore, lineWidth: selezionato ? 2 : 1)
                    .background(Tema.sfondo)
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(45))
                Image(systemName: root ? "lock.open.fill" : (server?.tracciamento ?? 0) > 0 ? "shield.lefthalf.filled" : "server.rack")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(colore)
            .bagliore(colore, raggio: selezionato || connesso ? 8 : 3)
            Text(ip).font(Tema.mono(9, .bold)).foregroundColor(colore)
            Text(server?.nome.components(separatedBy: " - ").last ?? "?")
                .font(Tema.mono(8)).foregroundColor(colore.opacity(0.6)).lineLimit(1)
        }
        .frame(width: 100)
    }
}

struct DettaglioNodo: View {
    let server: Server
    let aperte: Set<Int>
    let azione: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.nome).font(Tema.mono(14, .bold))
                    Text(server.ip).font(Tema.mono(11)).opacity(0.6)
                }
                Spacer()
                if server.tracciamento > 0 {
                    Label("\(server.tracciamento)s", systemImage: "scope")
                        .font(Tema.mono(11, .bold)).foregroundColor(Tema.ambra)
                }
            }
            HStack(spacing: 6) {
                ForEach(server.porte, id: \.numero) { p in
                    Text("\(p.numero) \(p.servizio)")
                        .font(Tema.mono(10, .bold))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .foregroundColor(aperte.contains(p.numero) ? .black : Tema.verde)
                        .background(aperte.contains(p.numero) ? Tema.verde : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Tema.verde.opacity(0.6)))
                }
                Spacer()
                Button("CONNETTI ›", action: azione).buttonStyle(TastoTerminale(colore: Tema.ciano))
            }
        }
        .foregroundColor(Tema.verde)
        .pannello()
    }
}

// MARK: - Posta

struct PostaView: View {
    @EnvironmentObject var motore: Motore
    @Binding var scheda: Scheda
    @State private var aperta: Int? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TitoloSezione(testo: "POSTA CIFRATA", colore: Tema.ambra)
                ForEach(motore.mailRicevute) { m in
                    let completata = motore.stato.missioniCompletate.contains(m.id)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Circle().fill(completata ? Color.clear : Tema.ambra).frame(width: 7, height: 7)
                                .padding(.top, 5).bagliore(Tema.ambra)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(m.mittente).font(Tema.mono(11)).opacity(0.6)
                                Text(m.oggetto).font(Tema.mono(14, .bold))
                            }
                            Spacer()
                            Text(completata ? "CHIUSA" : "+\(m.ricompensa) CR")
                                .font(Tema.mono(10, .bold))
                                .foregroundColor(completata ? Tema.verde.opacity(0.5) : Tema.ambra)
                        }
                        if aperta == m.id || (!completata && aperta == nil) {
                            Text(m.testo).font(Tema.mono(12)).opacity(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Label("Obiettivo: \(m.fileRichiesto)", systemImage: "doc.text.magnifyingglass")
                                    .font(Tema.mono(11, .bold)).foregroundColor(Tema.ciano)
                                Spacer()
                                if !completata {
                                    Button("RISPONDI ›") {
                                        motore.esegui("reply")
                                        scheda = .terminale
                                    }
                                    .buttonStyle(TastoTerminale(colore: Tema.ambra))
                                }
                            }
                        }
                    }
                    .foregroundColor(completata ? Tema.verde.opacity(0.6) : Tema.verde)
                    .pannello(completata ? Tema.verde.opacity(0.4) : Tema.ambra)
                    .onTapGesture { withAnimation { aperta = aperta == m.id ? -1 : m.id } }
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Negozio

struct NegozioView: View {
    @EnvironmentObject var motore: Motore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TitoloSezione(testo: "MERCATO NERO", colore: Tema.ciano)
                Text("Exploit verificati. Nessuna domanda, nessun rimborso.")
                    .font(Tema.mono(11)).foregroundColor(Tema.verde.opacity(0.5))

                ForEach(tuttiProgrammi, id: \.nome) { p in
                    let posseduto = motore.stato.programmi.contains(p.nome)
                    let accessibile = motore.stato.crediti >= p.prezzo
                    HStack(spacing: 12) {
                        Image(systemName: icona(p.nome))
                            .font(.system(size: 20))
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tema.verde.opacity(0.4)))
                            .bagliore(posseduto ? Tema.ciano : Tema.verde, raggio: 3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.nome).font(Tema.mono(15, .bold))
                            Text(p.descrizione).font(Tema.mono(11)).opacity(0.7)
                        }
                        Spacer()
                        if posseduto {
                            Text("INSTALLATO").font(Tema.mono(10, .bold)).foregroundColor(Tema.ciano)
                        } else {
                            Button("\(p.prezzo) CR") { motore.esegui("buy \(p.nome)") }
                                .buttonStyle(TastoTerminale(colore: accessibile ? Tema.verde : Tema.rosso))
                                .disabled(!accessibile)
                                .opacity(accessibile ? 1 : 0.6)
                        }
                    }
                    .foregroundColor(posseduto ? Tema.ciano : Tema.verde)
                    .pannello(posseduto ? Tema.ciano : Tema.verde)
                }
            }
            .padding(14)
        }
    }

    private var tuttiProgrammi: [Programma] {
        [Programma(nome: "sshcrack", descrizione: "Apre la porta 22 (SSH)", prezzo: 0),
         Programma(nome: "porthack", descrizione: "Ottiene l'accesso root", prezzo: 0)] + Livelli.programmiNegozio
    }

    private func icona(_ nome: String) -> String {
        switch nome {
        case "sshcrack": return "key.fill"
        case "porthack": return "bolt.horizontal.fill"
        case "ftpbounce": return "arrow.up.arrow.down"
        case "webworm": return "globe"
        case "smtpoverflow": return "envelope.badge.fill"
        case "tracekill": return "eye.slash.fill"
        default: return "cpu"
        }
    }
}
