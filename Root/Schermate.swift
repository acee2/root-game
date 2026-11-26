import SwiftUI

// MARK: - Evidenziazione dell'azione consigliata

struct Lampeggio: ViewModifier {
    let attivo: Bool
    @State private var fase = false
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Tema.ambra, lineWidth: 2)
                    .opacity(attivo ? (fase ? 1 : 0.25) : 0)
                    .shadow(color: Tema.ambra, radius: attivo ? 6 : 0)
                    .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { fase = true }
            }
    }
}

extension View {
    func consigliato(_ attivo: Bool) -> some View { modifier(Lampeggio(attivo: attivo)) }
}

/// Pulsante grande stile terminale per le azioni principali.
struct PulsanteAzione: View {
    let titolo: String
    var icona: String? = nil
    var colore: Color = Tema.verde
    var consigliato = false
    var abilitato = true
    let azione: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            azione()
        }) {
            HStack(spacing: 6) {
                if let icona { Image(systemName: icona) }
                Text(titolo).lineLimit(1).minimumScaleFactor(0.7)
            }
            .font(Tema.mono(12, .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundColor(abilitato ? colore : colore.opacity(0.35))
            .background(colore.opacity(abilitato ? 0.12 : 0.04))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(colore.opacity(abilitato ? 0.7 : 0.25)))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .disabled(!abilitato)
        .consigliato(consigliato && abilitato)
    }
}

// MARK: - Schermata principale (mappa/server + terminale)

struct OperazioniView: View {
    @EnvironmentObject var motore: Motore
    @Binding var scheda: Scheda
    var autoFocus = false

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if motore.connessoA != nil { ServerPanel(scheda: $scheda) } else { MappaView() }
            }
            .frame(width: 340)
            .frame(maxHeight: .infinity)
            Rectangle().fill(Tema.verde.opacity(0.2)).frame(width: 1)
            VStack(spacing: 0) {
                ChecklistView()
                Rectangle().fill(Tema.verde.opacity(0.2)).frame(height: 1)
                TerminaleView(autoFocus: autoFocus)
            }
        }
    }
}

// MARK: - Mappa di rete

struct MappaView: View {
    @EnvironmentObject var motore: Motore
    @State private var selezionato: String? = nil

    private var noti: [String] { motore.stato.ipConosciuti.sorted() }
    private var consigliato: String? {
        if case .connetti(let ip) = motore.guida.azione { return ip }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TitoloSezione(testo: "MAPPA DI RETE")
            GeometryReader { g in
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Canvas { ctx, size in
                            var x: CGFloat = 0
                            while x < size.width {
                                ctx.fill(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)), with: .color(Tema.verde.opacity(0.07)))
                                x += 20
                            }
                            var y: CGFloat = 0
                            while y < size.height {
                                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(Tema.verde.opacity(0.07)))
                                y += 20
                            }
                            for ip in noti {
                                guard let s = motore.info(ip), let a = punto(ip, size) else { continue }
                                for dest in s.collegamenti where noti.contains(dest) {
                                    guard let b = punto(dest, size) else { continue }
                                    var p = Path(); p.move(to: a); p.addLine(to: b)
                                    ctx.stroke(p, with: .color(Tema.verde.opacity(0.35)),
                                               style: StrokeStyle(lineWidth: 1, dash: [4, 4], dashPhase: CGFloat(-t * 12)))
                                    let f = CGFloat((t * 0.4).truncatingRemainder(dividingBy: 1))
                                    let q = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
                                    ctx.fill(Path(ellipseIn: CGRect(x: q.x - 2, y: q.y - 2, width: 4, height: 4)), with: .color(Tema.verde))
                                }
                            }
                        }
                        ForEach(noti, id: \.self) { ip in
                            if let p = punto(ip, g.size) {
                                NodoView(ip: ip, server: motore.info(ip), selezionato: selezionato == ip,
                                         consigliato: consigliato == ip, tempo: t)
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

            if let ip = selezionato ?? consigliato, let s = motore.info(ip) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.nome).font(Tema.mono(12, .bold)).lineLimit(1)
                        HStack(spacing: 6) {
                            Text(s.ip).opacity(0.6)
                            Text("\(s.porteRichieste) porte").opacity(0.6)
                            if s.tracciamento > 0 { Text("⚠ \(s.tracciamento)s").foregroundColor(Tema.ambra) }
                        }
                        .font(Tema.mono(10))
                    }
                    .foregroundColor(Tema.verde)
                    PulsanteAzione(titolo: "CONNETTI", icona: "link", colore: Tema.ciano, consigliato: consigliato == ip) {
                        motore.esegui("connect \(ip)")
                    }
                    .frame(width: 120)
                }
                .pannello()
            } else {
                Text("Tocca un server sulla mappa per collegarti").font(Tema.mono(11)).foregroundColor(Tema.verde.opacity(0.6)).pannello()
            }
        }
        .padding(10)
    }

    private func punto(_ ip: String, _ size: CGSize) -> CGPoint? {
        guard let p = Livelli.posizioni[ip] else { return nil }
        return CGPoint(x: 40 + p.x * (size.width - 80), y: 28 + p.y * (size.height - 64))
    }
}

struct NodoView: View {
    let ip: String
    let server: Server?
    let selezionato: Bool
    let consigliato: Bool
    let tempo: Double

    private var colore: Color {
        if consigliato { return Tema.ambra }
        return (server?.tracciamento ?? 0) > 0 ? Tema.rosso.opacity(0.85) : Tema.verde
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if consigliato || selezionato {
                    Circle().stroke(colore.opacity(0.6), lineWidth: 1)
                        .frame(width: 40 + CGFloat(sin(tempo * 4) * 5), height: 40 + CGFloat(sin(tempo * 4) * 5))
                }
                Rectangle()
                    .stroke(colore, lineWidth: selezionato ? 2 : 1)
                    .background(Tema.sfondo)
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(45))
                Image(systemName: (server?.tracciamento ?? 0) > 0 ? "shield.lefthalf.filled" : "server.rack")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(colore)
            .bagliore(colore, raggio: selezionato || consigliato ? 8 : 3)
            Text(server?.nome.components(separatedBy: " - ").last ?? ip)
                .font(Tema.mono(9, .bold)).foregroundColor(colore).lineLimit(1)
        }
        .frame(width: 96)
    }
}

// MARK: - Pannello del server connesso

struct ServerPanel: View {
    @EnvironmentObject var motore: Motore
    @Binding var scheda: Scheda

    var body: some View {
        if let s = motore.connessoA {
            let azione = motore.guida.azione
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: motore.haAccesso ? "lock.open.fill" : "lock.fill")
                        .foregroundColor(motore.haAccesso ? Tema.ciano : Tema.verde)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.nome).font(Tema.mono(13, .bold)).lineLimit(1)
                        Text("\(s.ip) · \(motore.haAccesso ? "ACCESSO ROOT" : "ospite")").font(Tema.mono(10)).opacity(0.6)
                    }
                    Spacer()
                    Button { motore.esegui("disconnect") } label: {
                        Label("ESCI", systemImage: "xmark").font(Tema.mono(11, .bold))
                    }
                    .buttonStyle(TastoTerminale(colore: Tema.rosso))
                    .consigliato(azione == .disconnetti)
                }
                .foregroundColor(Tema.verde)

                if motore.haAccesso { esploraFile(azione) } else { attacco(s, azione) }
            }
            .padding(10)
        }
    }

    // Fase 1: aprire le porte e lanciare porthack
    @ViewBuilder private func attacco(_ s: Server, _ azione: Motore.Azione) -> some View {
        TitoloSezione(testo: "PORTE \(motore.porteAperte.count)/\(s.porteRichieste)")
        ScrollView {
            VStack(spacing: 6) {
                ForEach(s.porte, id: \.numero) { p in
                    let aperta = motore.porteAperte.contains(p.numero)
                    let posseduto = motore.stato.programmi.contains(p.programma)
                    HStack(spacing: 10) {
                        Image(systemName: aperta ? "lock.open.fill" : "lock.fill")
                            .foregroundColor(aperta ? Tema.ciano : Tema.verde.opacity(0.6))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("PORTA \(p.numero)").font(Tema.mono(12, .bold))
                            Text("\(p.servizio) · si apre con \(p.programma)").font(Tema.mono(10)).opacity(0.6)
                        }
                        Spacer()
                        if aperta {
                            Text("APERTA").font(Tema.mono(11, .bold)).foregroundColor(Tema.ciano)
                        } else if posseduto {
                            PulsanteAzione(titolo: p.programma, icona: "bolt.fill", consigliato: azione == .porta(p.numero)) {
                                motore.esegui("\(p.programma) \(p.numero)")
                            }
                            .frame(width: 140)
                        } else {
                            PulsanteAzione(titolo: "COMPRA", icona: "cart", colore: Tema.ambra,
                                           consigliato: azione == .compra(p.programma)) { scheda = .shop }
                                .frame(width: 140)
                        }
                    }
                    .foregroundColor(Tema.verde)
                    .padding(8)
                    .background(Tema.pannello)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke((aperta ? Tema.ciano : Tema.verde).opacity(0.3)))
                }
            }
        }
        PulsanteAzione(titolo: "OTTIENI ACCESSO (porthack)", icona: "bolt.horizontal.fill", colore: Tema.ciano,
                       consigliato: azione == .porthack,
                       abilitato: motore.porteAperte.count >= s.porteRichieste) {
            motore.esegui("porthack")
        }
    }

    // Fase 2: esplorare i file
    @ViewBuilder private func esploraFile(_ azione: Motore.Azione) -> some View {
        let obiettivo: String? = { if case .scarica(let p) = azione { return p }; return nil }()
        HStack(spacing: 6) {
            Button { motore.esegui("cd ..") } label: { Image(systemName: "chevron.left") }
                .buttonStyle(TastoTerminale())
                .disabled(motore.cartella == "/")
                .opacity(motore.cartella == "/" ? 0.3 : 1)
            Text(motore.cartella).font(Tema.mono(12, .bold)).foregroundColor(Tema.ciano).lineLimit(1)
            Spacer()
        }
        ScrollView {
            VStack(spacing: 4) {
                ForEach(motore.vociCartella()) { v in
                    let sullaStrada = obiettivo.map { v.cartella ? $0.hasPrefix(v.percorso + "/") : $0 == v.percorso } ?? false
                    HStack(spacing: 8) {
                        Image(systemName: v.cartella ? "folder.fill" : (v.file?.password != nil ? "lock.doc.fill" : "doc.text"))
                            .foregroundColor(v.cartella ? Tema.ambra : Tema.verde)
                            .frame(width: 18)
                        Text(v.nome + (v.cartella ? "/" : "")).font(Tema.mono(12, .bold)).lineLimit(1)
                        Spacer()
                        if v.cartella {
                            Image(systemName: "chevron.right").opacity(0.5)
                        } else {
                            Button { motore.esegui("cat \(v.percorso)") } label: { Image(systemName: "eye") }
                                .buttonStyle(TastoTerminale())
                            Button { motore.esegui("download \(v.percorso)") } label: { Image(systemName: "arrow.down.to.line") }
                                .buttonStyle(TastoTerminale(colore: Tema.ciano))
                                .consigliato(sullaStrada)
                        }
                    }
                    .foregroundColor(Tema.verde)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Tema.pannello)
                    .contentShape(Rectangle())
                    .onTapGesture { if v.cartella { motore.esegui("cd \(v.percorso)") } }
                    .consigliato(sullaStrada && v.cartella)
                }
            }
        }
        HStack(spacing: 6) {
            PulsanteAzione(titolo: "TROVA SERVER", icona: "dot.radiowaves.left.and.right", consigliato: azione == .scansiona) {
                motore.esegui("scan")
            }
            PulsanteAzione(titolo: "CANCELLA LOG", icona: "trash", colore: Tema.rosso,
                           consigliato: azione == .cancellaLog, abilitato: motore.logPresenti) {
                motore.esegui("rm /log/*")
            }
        }
    }
}

// MARK: - Terminale

struct TerminaleView: View {
    @EnvironmentObject var motore: Motore
    var autoFocus = false
    @State private var input = ""
    @State private var indiceCronologia: Int? = nil
    @State private var cursore = true
    @FocusState private var focus: Bool

    private var prompt: String {
        guard let s = motore.connessoA else { return "ghost@locale:~$" }
        return "\(motore.haAccesso ? "root" : "guest")@\(s.ip):\(motore.cartella)$"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(motore.righe) { r in RigaView(riga: r).id(r.id) }
                        Color.clear.frame(height: 2).id("fondo")
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                }
                .onChange(of: motore.righe.count) { _ in
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("fondo", anchor: .bottom) }
                }
                .onAppear { proxy.scrollTo("fondo", anchor: .bottom) }
                .onTapGesture { focus = true }
            }
            HStack(spacing: 6) {
                Text(prompt)
                    .font(Tema.mono(11, .bold))
                    .foregroundColor(motore.haAccesso ? Tema.ciano : Tema.verde)
                    .lineLimit(1)
                ZStack(alignment: .leading) {
                    if input.isEmpty && !focus {
                        Text(cursore ? "█ comandi" : "  comandi")
                            .foregroundColor(Tema.verde.opacity(0.4))
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
                .font(Tema.mono(12))
                if focus {
                    Button("↑") { cronologia(-1) }.buttonStyle(TastoTerminale())
                    Button("TAB") { completa() }.buttonStyle(TastoTerminale(colore: Tema.ambra))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
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
        }
    }
}

struct RigaView: View {
    let riga: Riga

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            if riga.tipo == .errore { Text("✖").foregroundColor(Tema.rosso) }
            if riga.tipo == .successo { Text("✔").foregroundColor(Tema.ciano) }
            if riga.tipo == .sistema { Text("»").foregroundColor(Tema.ambra) }
            Text(riga.testo)
                .foregroundColor(colore)
                .fontWeight(riga.tipo == .comando ? .bold : .regular)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .font(Tema.mono(11.5))
        .bagliore(colore, raggio: riga.tipo == .normale ? 2 : 3)
        .padding(.top, riga.tipo == .comando ? 6 : 0)
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

// MARK: - Posta (lista + dettaglio)

struct PostaView: View {
    @EnvironmentObject var motore: Motore
    @Binding var scheda: Scheda
    @State private var aperta: Int? = nil

    var body: some View {
        let mail = motore.mailRicevute
        let selezionata = mail.first { $0.id == (aperta ?? motore.stato.missioneCorrente) } ?? mail.first
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    TitoloSezione(testo: "POSTA", colore: Tema.ambra)
                    ForEach(mail) { m in
                        let chiusa = motore.stato.missioniCompletate.contains(m.id)
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(chiusa ? Color.clear : Tema.ambra).frame(width: 7, height: 7).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.oggetto).font(Tema.mono(12, .bold)).lineLimit(1)
                                Text(chiusa ? "completata" : "+\(m.ricompensa) CR").font(Tema.mono(10)).opacity(0.6)
                            }
                            Spacer()
                        }
                        .foregroundColor(chiusa ? Tema.verde.opacity(0.5) : Tema.verde)
                        .padding(8)
                        .background(selezionata?.id == m.id ? Tema.verde.opacity(0.1) : Tema.pannello)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tema.verde.opacity(selezionata?.id == m.id ? 0.6 : 0.2)))
                        .onTapGesture { aperta = m.id }
                    }
                }
                .padding(10)
            }
            .frame(width: 250)
            Rectangle().fill(Tema.verde.opacity(0.2)).frame(width: 1)
            if let m = selezionata {
                let chiusa = motore.stato.missioniCompletate.contains(m.id)
                VStack(alignment: .leading, spacing: 10) {
                    Text("DA: \(m.mittente)").font(Tema.mono(11)).opacity(0.6)
                    Text(m.oggetto).font(Tema.mono(17, .bold)).bagliore()
                    ScrollView {
                        Text(m.testo).font(Tema.mono(13)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 10) {
                        Label("Consegna: \(m.fileRichiesto)", systemImage: "doc.text.magnifyingglass")
                            .font(Tema.mono(12, .bold)).foregroundColor(Tema.ciano)
                        Spacer()
                        if !chiusa {
                            PulsanteAzione(titolo: "RISPONDI E CONSEGNA", icona: "paperplane.fill", colore: Tema.ambra,
                                           consigliato: motore.guida.azione == .rispondi) {
                                motore.esegui("reply")
                            }
                            .frame(width: 230)
                        } else {
                            Text("✔ COMPLETATA").font(Tema.mono(12, .bold)).foregroundColor(Tema.ciano)
                        }
                    }
                }
                .foregroundColor(Tema.verde)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

// MARK: - File locali (con decifratura)

struct FileLocaliView: View {
    @EnvironmentObject var motore: Motore
    @State private var selezionato: String? = nil
    @State private var password = ""

    var body: some View {
        let files = motore.stato.fileScaricati
        let nomeSel = selezionato ?? files.last.map { nome($0) }
        let file = files.first { nome($0) == nomeSel }
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    TitoloSezione(testo: "IL TUO PC")
                    if files.isEmpty {
                        Text("Nessun file. Scaricali dai server.").font(Tema.mono(11)).opacity(0.6)
                    }
                    ForEach(files, id: \.percorso) { f in
                        HStack(spacing: 8) {
                            Image(systemName: f.password != nil ? "lock.doc.fill" : "doc.text")
                                .foregroundColor(f.password != nil ? Tema.ambra : Tema.verde)
                            Text(nome(f)).font(Tema.mono(12, .bold)).lineLimit(1)
                            Spacer()
                        }
                        .foregroundColor(Tema.verde)
                        .padding(8)
                        .background(nomeSel == nome(f) ? Tema.verde.opacity(0.1) : Tema.pannello)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tema.verde.opacity(nomeSel == nome(f) ? 0.6 : 0.2)))
                        .onTapGesture { selezionato = nome(f); password = "" }
                        .consigliato(motore.guida.azione == .decifra(nome(f)) && nomeSel != nome(f))
                    }
                }
                .padding(10)
            }
            .frame(width: 250)
            Rectangle().fill(Tema.verde.opacity(0.2)).frame(width: 1)
            VStack(alignment: .leading, spacing: 10) {
                if let f = file {
                    Text(nome(f)).font(Tema.mono(16, .bold)).bagliore()
                    Text(f.percorso).font(Tema.mono(10)).opacity(0.5)
                    if f.password != nil {
                        Text("▓▓▒░ FILE CIFRATO ░▒▓▓").font(Tema.mono(14, .bold)).foregroundColor(Tema.ambra)
                        Text("Serve una password. Spesso le persone la scrivono nei loro file di testo…")
                            .font(Tema.mono(11)).opacity(0.7)
                        HStack(spacing: 8) {
                            TextField("password", text: $password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(Tema.mono(13))
                                .padding(8)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tema.ambra.opacity(0.6)))
                                .onSubmit { motore.esegui("decrypt \(nome(f)) \(password)") }
                            PulsanteAzione(titolo: "DECIFRA", icona: "key.fill", colore: Tema.ambra,
                                           consigliato: !password.isEmpty, abilitato: !password.isEmpty) {
                                motore.esegui("decrypt \(nome(f)) \(password)")
                            }
                            .frame(width: 130)
                        }
                    } else {
                        ScrollView {
                            Text(f.contenuto).font(Tema.mono(13)).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Text("Seleziona un file").font(Tema.mono(12)).opacity(0.5)
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(Tema.verde)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func nome(_ f: FileVirtuale) -> String { String(f.percorso.split(separator: "/").last ?? "") }
}

// MARK: - Shop

struct ShopView: View {
    @EnvironmentObject var motore: Motore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TitoloSezione(testo: "MERCATO NERO", colore: Tema.ciano)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(tuttiProgrammi, id: \.nome) { p in
                        let posseduto = motore.stato.programmi.contains(p.nome)
                        let accessibile = motore.stato.crediti >= p.prezzo
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: icona(p.nome)).font(.system(size: 18))
                                Spacer()
                                if posseduto { Text("INSTALLATO").font(Tema.mono(9, .bold)) }
                            }
                            Text(p.nome).font(Tema.mono(14, .bold))
                            Text(p.descrizione).font(Tema.mono(10)).opacity(0.7).lineLimit(2, reservesSpace: true)
                            if !posseduto {
                                PulsanteAzione(titolo: "\(p.prezzo) CR", icona: "cart", colore: accessibile ? Tema.verde : Tema.rosso,
                                               consigliato: motore.guida.azione == .compra(p.nome), abilitato: accessibile) {
                                    motore.esegui("buy \(p.nome)")
                                }
                            }
                        }
                        .foregroundColor(posseduto ? Tema.ciano : Tema.verde)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .pannello(posseduto ? Tema.ciano : Tema.verde)
                    }
                }
            }
            .padding(12)
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

// MARK: - Checklist della missione

struct ChecklistView: View {
    @EnvironmentObject var motore: Motore
    @State private var aperta = true

    var body: some View {
        let passi = motore.passiMissione
        let attuale = passi.first { !$0.fatto }?.id
        VStack(alignment: .leading, spacing: 4) {
            Button { withAnimation { aperta.toggle() } } label: {
                HStack {
                    Text("MISSIONE: \(motore.missioneAttuale?.oggetto.uppercased() ?? "—")").font(Tema.mono(11, .heavy)).lineLimit(1)
                    Spacer()
                    Text("\(passi.filter(\.fatto).count)/\(passi.count)").font(Tema.mono(11, .bold))
                    Image(systemName: aperta ? "chevron.up" : "chevron.down").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(Tema.ambra)
            }
            if aperta {
                ForEach(passi) { p in
                    HStack(spacing: 8) {
                        Image(systemName: p.fatto ? "checkmark.square.fill" : (p.id == attuale ? "arrow.right.square.fill" : "square"))
                            .foregroundColor(p.fatto ? Tema.ciano : (p.id == attuale ? Tema.ambra : Tema.verde.opacity(0.4)))
                        Text(p.testo)
                            .strikethrough(p.fatto, color: Tema.ciano.opacity(0.6))
                            .foregroundColor(p.fatto ? Tema.ciano.opacity(0.6) : (p.id == attuale ? Tema.ambra : Tema.verde.opacity(0.55)))
                            .fontWeight(p.id == attuale ? .bold : .regular)
                    }
                    .font(Tema.mono(11))
                    .bagliore(p.id == attuale ? Tema.ambra : .clear, raggio: 3)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Tema.pannello)
    }
}
