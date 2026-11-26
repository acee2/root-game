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
            EffettoCRT().allowsHitTesting(false).ignoresSafeArea()
        }
        .onAppear {
            switch demo {
            case nil, "avvio": break
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
