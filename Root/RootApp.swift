import SwiftUI

@main
struct RootApp: App {
    @StateObject private var motore = Motore()
    var body: some Scene {
        WindowGroup {
            ContenitoreView()
                .environmentObject(motore)
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
        }
    }
}

enum Scheda: String, CaseIterable {
    case terminale = "TERM", rete = "RETE", posta = "POSTA", negozio = "SHOP"
    var icona: String {
        switch self {
        case .terminale: return "chevron.left.forwardslash.chevron.right"
        case .rete: return "point.3.connected.trianglepath.dotted"
        case .posta: return "envelope"
        case .negozio: return "cpu"
        }
    }
}

struct ContenitoreView: View {
    @EnvironmentObject var motore: Motore
    private let demo = ProcessInfo.processInfo.environment["ROOT_DEMO"]
    @State private var avviato = false
    @State private var scheda: Scheda = .terminale

    var body: some View {
        ZStack {
            Tema.sfondo.ignoresSafeArea()
            if avviato {
                VStack(spacing: 0) {
                    BarraStato()
                    Group {
                        switch scheda {
                        case .terminale: TerminaleView(autoFocus: demo == nil)
                        case .rete: ReteView(scheda: $scheda)
                        case .posta: PostaView(scheda: $scheda)
                        case .negozio: NegozioView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    BarraSchede(scheda: $scheda)
                }
                .transition(.opacity)
            } else {
                AvvioView { withAnimation(.easeIn(duration: 0.4)) { avviato = true } }
            }
            EffettoCRT().allowsHitTesting(false).ignoresSafeArea()
        }
        .onAppear {
            switch demo {
            case "terminale": avviato = true; scheda = .terminale
            case "rete": avviato = true; scheda = .rete
            case "posta": avviato = true; scheda = .posta
            case "negozio": avviato = true; scheda = .negozio
            default: break
            }
        }
    }
}

// MARK: - Barra di stato superiore

struct BarraStato: View {
    @EnvironmentObject var motore: Motore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(motore.connessoA == nil ? Color.gray : (motore.haAccesso ? Tema.ciano : Tema.verde))
                    .frame(width: 8, height: 8)
                    .bagliore(motore.connessoA == nil ? .clear : Tema.verde)
                VStack(alignment: .leading, spacing: 1) {
                    Text(motore.connessoA?.nome.uppercased() ?? "OFFLINE")
                        .font(Tema.mono(12, .bold)).lineLimit(1)
                    Text(motore.connessoA.map { "\($0.ip)\(motore.haAccesso ? "  ROOT" : "")" } ?? "nessuna connessione")
                        .font(Tema.mono(10)).opacity(0.6)
                }
                Spacer()
                Text("\(motore.stato.crediti) CR")
                    .font(Tema.mono(13, .bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tema.verde.opacity(0.5)))
            }
            .foregroundColor(Tema.verde)
            .padding(.horizontal, 14).padding(.vertical, 8)

            if let t = motore.tempoRimasto, let totale = motore.connessoA?.tracciamento, totale > 0 {
                BarraTraccia(rimasto: t, totale: max(totale, t))
            } else {
                Rectangle().fill(Tema.verde.opacity(0.25)).frame(height: 1)
            }
        }
        .background(Tema.pannello)
    }
}

struct BarraTraccia: View {
    let rimasto: Int
    let totale: Int
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("⚠ TRACCIAMENTO IN CORSO").font(Tema.mono(11, .bold))
                Spacer()
                Text(String(format: "00:%02d", rimasto)).font(Tema.mono(13, .heavy))
            }
            .foregroundColor(Tema.rosso)
            .bagliore(Tema.rosso)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Tema.rosso.opacity(0.15))
                    Rectangle().fill(Tema.rosso)
                        .frame(width: g.size.width * CGFloat(rimasto) / CGFloat(totale))
                        .bagliore(Tema.rosso, raggio: 6)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Tema.rosso.opacity(rimasto % 2 == 0 ? 0.14 : 0.07))
        .animation(.linear(duration: 0.3), value: rimasto)
    }
}

// MARK: - Barra schede inferiore

struct BarraSchede: View {
    @Binding var scheda: Scheda
    @EnvironmentObject var motore: Motore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Scheda.allCases, id: \.self) { s in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    scheda = s
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: s.icona).font(.system(size: 17, weight: .medium))
                            if s == .posta && !motore.stato.missioniCompletate.contains(motore.stato.missioneCorrente)
                                && motore.missioneAttuale != nil {
                                Circle().fill(Tema.ambra).frame(width: 7, height: 7).offset(x: 6, y: -3)
                            }
                        }
                        Text(s.rawValue).font(Tema.mono(10, .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(scheda == s ? Tema.verde : Tema.verde.opacity(0.35))
                    .bagliore(scheda == s ? Tema.verde : .clear)
                    .overlay(alignment: .top) {
                        Rectangle().fill(scheda == s ? Tema.verde : .clear).frame(height: 2)
                    }
                }
            }
        }
        .background(Tema.pannello)
        .overlay(alignment: .top) { Rectangle().fill(Tema.verde.opacity(0.25)).frame(height: 1) }
    }
}

// MARK: - Schermata di avvio

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
        "[ OK ] Caricamento kernel ROOT OS 0.2",
        "[ OK ] Montaggio file system cifrato",
        "[ OK ] Avvio modulo di rete anonima",
        "[ OK ] Instradamento tramite 7 proxy",
        "[ OK ] Verifica integrità programmi",
        "[ !! ] Messaggio a orologeria rilevato",
        "[ OK ] Sessione pronta",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text(logo)
                .font(Tema.mono(10.5, .bold))
                .foregroundColor(Tema.verde)
                .bagliore(Tema.verde, raggio: 8)
                .frame(maxWidth: .infinity)
            Text("anonymous terminal · build 0.2")
                .font(Tema.mono(11)).foregroundColor(Tema.verde.opacity(0.5))
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<righeVisibili, id: \.self) { i in
                    Text(log[i])
                        .font(Tema.mono(12))
                        .foregroundColor(log[i].hasPrefix("[ !!") ? Tema.ambra : Tema.verde.opacity(0.85))
                }
            }
            .frame(height: 150, alignment: .top)
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().stroke(Tema.verde.opacity(0.5))
                        Rectangle().fill(Tema.verde).frame(width: g.size.width * progresso).bagliore()
                    }
                }
                .frame(height: 10)
                Text("\(Int(progresso * 100))%").font(Tema.mono(11)).foregroundColor(Tema.verde)
            }
            Spacer()
        }
        .padding(28)
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
            try? await Task.sleep(nanoseconds: 700_000_000)
            if ProcessInfo.processInfo.environment["ROOT_DEMO"] == nil { fine() }
        }
    }
}
