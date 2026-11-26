import SwiftUI

@main
struct RootApp: App {
    @StateObject private var motore = Motore()
    var body: some Scene {
        WindowGroup {
            ContenitoreView()
                .environmentObject(motore)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .statusBarHidden(true)
        }
    }
}

enum Scheda: String, CaseIterable {
    case operazioni = "HACK", posta = "POSTA", file = "FILE", shop = "SHOP"
    var icona: String {
        switch self {
        case .operazioni: return "terminal"
        case .posta: return "envelope"
        case .file: return "folder"
        case .shop: return "cpu"
        }
    }
}

struct ContenitoreView: View {
    @EnvironmentObject var motore: Motore
    private let demo = ProcessInfo.processInfo.environment["ROOT_DEMO"]
    @State private var avviato = false
    @State private var scheda: Scheda = .operazioni

    var body: some View {
        ZStack {
            Tema.sfondo.ignoresSafeArea()
            if avviato {
                HStack(spacing: 0) {
                    BarraLaterale(scheda: $scheda)
                    VStack(spacing: 0) {
                        BarraStato(scheda: $scheda)
                        Group {
                            switch scheda {
                            case .operazioni: OperazioniView(scheda: $scheda, autoFocus: false)
                            case .posta: PostaView(scheda: $scheda)
                            case .file: FileLocaliView()
                            case .shop: ShopView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .transition(.opacity)
            } else {
                AvvioView { withAnimation(.easeIn(duration: 0.4)) { avviato = true } }
            }
            if avviato, let a = motore.avviso {
                AvvisoView(avviso: a)
                    .id(a.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 54)
                    .allowsHitTesting(false)
            }
            if avviato && motore.stato.tutorialVisto != true {
                TutorialView { withAnimation { motore.completaTutorial() } }
                    .transition(.opacity)
            }
            EffettoCRT().allowsHitTesting(false).ignoresSafeArea()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: motore.avviso)
        .onAppear {
            switch demo {
            case nil, "avvio": break
            case "tutorial": avviato = true
            case "posta": avviato = true; scheda = .posta
            case "file": avviato = true; scheda = .file
            case "shop": avviato = true; scheda = .shop
            default: avviato = true; scheda = .operazioni
            }
        }
    }
}

// MARK: - Barra laterale (schede)

struct BarraLaterale: View {
    @Binding var scheda: Scheda
    @EnvironmentObject var motore: Motore

    var body: some View {
        VStack(spacing: 4) {
            Text(">_").font(Tema.mono(16, .heavy)).foregroundColor(Tema.verde).bagliore().padding(.vertical, 8)
            ForEach(Scheda.allCases, id: \.self) { s in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    scheda = s
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: s.icona).font(.system(size: 17, weight: .medium))
                        Text(s.rawValue).font(Tema.mono(9, .bold))
                    }
                    .frame(width: 58, height: 52)
                    .foregroundColor(scheda == s ? Tema.verde : Tema.verde.opacity(0.4))
                    .background(scheda == s ? Tema.verde.opacity(0.1) : .clear)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(scheda == s ? Tema.verde : .clear).frame(width: 2)
                    }
                    .overlay(alignment: .topTrailing) {
                        if consigliata(s) && scheda != s {
                            Circle().fill(Tema.ambra).frame(width: 8, height: 8).bagliore(Tema.ambra).padding(8)
                        }
                    }
                    .bagliore(scheda == s ? Tema.verde : .clear, raggio: 3)
                }
            }
            Spacer()
        }
        .frame(width: 62)
        .background(Tema.pannello)
        .overlay(alignment: .trailing) { Rectangle().fill(Tema.verde.opacity(0.25)).frame(width: 1) }
    }

    private func consigliata(_ s: Scheda) -> Bool {
        switch (motore.guida.azione, s) {
        case (.rispondi, .posta), (.decifra, .file), (.compra, .shop): return true
        default: return false
        }
    }
}

// MARK: - Barra di stato con obiettivo

struct BarraStato: View {
    @EnvironmentObject var motore: Motore
    @Binding var scheda: Scheda

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // obiettivo
                HStack(spacing: 8) {
                    Image(systemName: "scope").foregroundColor(Tema.ambra)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PROSSIMO PASSO").font(Tema.mono(9, .bold)).foregroundColor(Tema.ambra.opacity(0.7))
                        Text(motore.guida.testo).font(Tema.mono(12, .bold)).foregroundColor(Tema.ambra).lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .bagliore(Tema.ambra, raggio: 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { vaiAllaGuida() }

                if motore.guida.azione != .nessuna {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        vaiAllaGuida()
                        if case .decifra = motore.guida.azione {} else { motore.eseguiGuida() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(etichettaGuida)
                            Image(systemName: "chevron.right")
                        }
                        .font(Tema.mono(12, .heavy))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Tema.ambra)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .bagliore(Tema.ambra, raggio: 6)
                    }
                }

                if let t = motore.tempoRimasto {
                    HStack(spacing: 6) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text(String(format: "TRACCIA 00:%02d", t)).font(Tema.mono(13, .heavy))
                    }
                    .foregroundColor(Tema.rosso)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Tema.rosso.opacity(t % 2 == 0 ? 0.22 : 0.1))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tema.rosso.opacity(0.7)))
                    .bagliore(Tema.rosso)
                }

                Text("\(motore.stato.crediti) CR")
                    .font(Tema.mono(13, .bold))
                    .foregroundColor(Tema.verde)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tema.verde.opacity(0.5)))
            }
            .padding(.horizontal, 14).padding(.vertical, 7)

            if let t = motore.tempoRimasto, let totale = motore.connessoA?.tracciamento, totale > 0 {
                GeometryReader { g in
                    Rectangle().fill(Tema.rosso)
                        .frame(width: g.size.width * CGFloat(t) / CGFloat(max(totale, t)))
                        .bagliore(Tema.rosso, raggio: 5)
                        .animation(.linear(duration: 1), value: t)
                }
                .frame(height: 2)
            } else {
                Rectangle().fill(Tema.verde.opacity(0.25)).frame(height: 1)
            }
        }
        .background(Tema.pannello)
    }

    private var etichettaGuida: String {
        switch motore.guida.azione {
        case .connetti: return "CONNETTI"
        case .porta: return "APRI PORTA"
        case .porthack: return "ENTRA"
        case .scarica: return "SCARICA"
        case .cancellaLog: return "CANCELLA LOG"
        case .scansiona: return "SCANSIONA"
        case .rispondi: return "CONSEGNA"
        case .compra: return "COMPRA"
        case .decifra: return "VAI AI FILE"
        case .disconnetti: return "ESCI"
        case .nessuna: return ""
        }
    }

    private func vaiAllaGuida() {
        switch motore.guida.azione {
        case .rispondi: scheda = .posta
        case .decifra: scheda = .file
        case .compra: scheda = .shop
        case .nessuna: break
        default: scheda = .operazioni
        }
    }
}

// MARK: - Avvio

struct AvvioView: View {
    let fine: () -> Void
    @State private var righeVisibili = 0
    @State private var progresso: CGFloat = 0

    private let logo = """
    ██████╗  ██████╗  ██████╗ ████████╗
    ██╔══██╗██╔═══██╗██╔═══██╗╚══██╔══╝
    ██████╔╝██║   ██║██║   ██║   ██║
    ██╔══██╗██║   ██║██║   ██║   ██║
    ██║  ██║╚██████╔╝╚██████╔╝   ██║
    ╚═╝  ╚═╝ ╚═════╝  ╚═════╝    ╚═╝
    """

    private let log = [
        "[ OK ] Caricamento kernel ROOT OS 0.3",
        "[ OK ] Montaggio file system cifrato",
        "[ OK ] Avvio modulo di rete anonima",
        "[ OK ] Instradamento tramite 7 proxy",
        "[ OK ] Verifica integrità programmi",
        "[ !! ] Messaggio a orologeria rilevato",
        "[ OK ] Sessione pronta",
    ]

    var body: some View {
        HStack(spacing: 40) {
            VStack(spacing: 14) {
                Text(logo)
                    .font(Tema.mono(11, .bold))
                    .foregroundColor(Tema.verde)
                    .bagliore(Tema.verde, raggio: 8)
                Text("anonymous terminal · build 0.3")
                    .font(Tema.mono(11)).foregroundColor(Tema.verde.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<righeVisibili, id: \.self) { i in
                        Text(log[i])
                            .font(Tema.mono(12))
                            .foregroundColor(log[i].hasPrefix("[ !!") ? Tema.ambra : Tema.verde.opacity(0.85))
                    }
                }
                .frame(width: 330, height: 150, alignment: .topLeading)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().stroke(Tema.verde.opacity(0.5))
                        Rectangle().fill(Tema.verde).frame(width: g.size.width * progresso).bagliore()
                    }
                }
                .frame(width: 330, height: 10)
                Text(progresso >= 1 ? "TOCCA PER INIZIARE" : "\(Int(progresso * 100))%")
                    .font(Tema.mono(11, .bold)).foregroundColor(Tema.verde)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { fine() }
        .task {
            for i in 1...log.count {
                try? await Task.sleep(nanoseconds: 380_000_000)
                withAnimation(.easeOut(duration: 0.3)) {
                    righeVisibili = i
                    progresso = CGFloat(i) / CGFloat(log.count)
                }
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            if ProcessInfo.processInfo.environment["ROOT_DEMO"] == nil { fine() }
        }
    }
}

// MARK: - Avviso a comparsa

struct AvvisoView: View {
    let avviso: Motore.Avviso
    private var colore: Color {
        switch avviso.tipo {
        case .errore: return Tema.rosso
        case .successo: return Tema.ciano
        default: return Tema.verde
        }
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: avviso.icona).font(.system(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(avviso.titolo).font(Tema.mono(15, .heavy))
                Text(avviso.testo).font(Tema.mono(11)).opacity(0.85)
            }
        }
        .foregroundColor(colore)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.black.opacity(0.92))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(colore, lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .bagliore(colore, raggio: 10)
    }
}

// MARK: - Tutorial iniziale

struct TutorialView: View {
    let fine: () -> Void

    private let passi: [(String, String, String)] = [
        ("map", "1. SCEGLI UN SERVER", "Sulla mappa tocca un server e premi Connetti."),
        ("lock.open", "2. APRI LE PORTE", "Usa i tuoi programmi per aprire le porte, poi premi Ottieni accesso."),
        ("arrow.down.doc", "3. RUBA IL FILE", "Esplora le cartelle e scarica il file che ti serve."),
        ("trash", "4. NON FARTI PRENDERE", "Se c'è il timer rosso, cancella i log ed esci prima dello zero."),
        ("paperplane", "5. CONSEGNA", "Rispondi alla mail nella Posta per guadagnare crediti."),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("COME SI GIOCA").font(Tema.mono(20, .heavy)).foregroundColor(Tema.verde).bagliore(Tema.verde, raggio: 8)
                HStack(alignment: .top, spacing: 10) {
                    ForEach(passi, id: \.1) { p in
                        VStack(spacing: 8) {
                            Image(systemName: p.0).font(.system(size: 26)).foregroundColor(Tema.ciano).bagliore(Tema.ciano)
                                .frame(height: 34)
                            Text(p.1).font(Tema.mono(11, .heavy)).multilineTextAlignment(.center)
                            Text(p.2).font(Tema.mono(10)).opacity(0.75).multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundColor(Tema.verde)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .pannello()
                    }
                }
                .frame(height: 170)
                HStack(spacing: 10) {
                    Image(systemName: "scope").foregroundColor(Tema.ambra)
                    Text("Bloccato? Guarda PROSSIMO PASSO in alto: il pulsante giallo lo fa per te.")
                        .font(Tema.mono(12, .bold)).foregroundColor(Tema.ambra)
                }
                PulsanteAzione(titolo: "INIZIA", icona: "play.fill", colore: Tema.ambra, consigliato: true, azione: fine)
                    .frame(width: 220)
            }
            .padding(.horizontal, 50)
        }
    }
}
