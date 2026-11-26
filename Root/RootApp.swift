import SwiftUI

@main
struct RootApp: App {
    @StateObject private var motore = Motore()
    var body: some Scene {
        WindowGroup {
            TerminaleView()
                .environmentObject(motore)
                .preferredColorScheme(.dark)
        }
    }
}

let verdeTerminale = Color(red: 0.2, green: 1.0, blue: 0.45)

struct TerminaleView: View {
    @EnvironmentObject var motore: Motore
    @State private var input = ""
    @State private var indiceCronologia: Int? = nil
    @FocusState private var focus: Bool

    private let rapidi = ["help", "mail", "reply", "probe", "porthack", "ls", "cd ..", "scan", "status", "store", "files", "disconnect"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                barraStato
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(motore.righe) { r in
                                Text(r.testo)
                                    .foregroundColor(colore(r.tipo))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .id(r.id)
                            }
                        }
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                    }
                    .onChange(of: motore.righe.count) { _ in
                        if let ultimo = motore.righe.last { withAnimation { proxy.scrollTo(ultimo.id, anchor: .bottom) } }
                    }
                    .onTapGesture { focus = true }
                }
                barraRapida
                rigaInput
            }
            EffettoCRT().allowsHitTesting(false).ignoresSafeArea()
        }
        .onAppear { focus = true }
    }

    private var barraStato: some View {
        HStack {
            Text(motore.connessoA.map { "● \($0.nome)" } ?? "○ offline")
                .lineLimit(1)
            Spacer()
            if let t = motore.tempoRimasto {
                Text("TRACCIA \(t)s")
                    .bold()
                    .foregroundColor(.red)
                    .opacity(t % 2 == 0 ? 1 : 0.5)
            }
            Text("\(motore.stato.crediti) cr")
        }
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundColor(verdeTerminale)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(motore.tempoRimasto != nil ? Color.red.opacity(0.15) : Color.white.opacity(0.05))
    }

    private var barraRapida: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button("↑") { cronologia(-1) }
                Button("↓") { cronologia(1) }
                ForEach(rapidi, id: \.self) { c in
                    Button(c) { esegui(c) }
                }
            }
            .buttonStyle(TastoTerminale())
            .padding(.horizontal, 8).padding(.vertical, 6)
        }
        .background(Color.white.opacity(0.04))
    }

    private var rigaInput: some View {
        HStack(spacing: 6) {
            Text("$").foregroundColor(verdeTerminale)
            TextField("", text: $input)
                .focused($focus)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .foregroundColor(verdeTerminale)
                .tint(verdeTerminale)
                .onSubmit { esegui(input); focus = true }
            Button("Tab") { completa() }.buttonStyle(TastoTerminale())
        }
        .font(.system(size: 15, design: .monospaced))
        .padding(10)
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

    /// Autocompletamento semplice di comandi e IP noti.
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

    private func colore(_ t: Riga.Tipo) -> Color {
        switch t {
        case .normale: return verdeTerminale.opacity(0.85)
        case .comando: return .white
        case .errore: return Color(red: 1, green: 0.35, blue: 0.35)
        case .successo: return Color(red: 0.4, green: 1, blue: 1)
        case .sistema: return Color(red: 1, green: 0.75, blue: 0.2)
        }
    }
}

struct TastoTerminale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(verdeTerminale)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).stroke(verdeTerminale.opacity(0.5)))
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

/// Scanline e vignettatura stile monitor CRT.
struct EffettoCRT: View {
    var body: some View {
        ZStack {
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height {
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.25)))
                    y += 3
                }
            }
            RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 200, endRadius: 600)
        }
    }
}
