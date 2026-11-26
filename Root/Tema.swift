import SwiftUI

enum Tema {
    static let verde = Color(red: 0.2, green: 1.0, blue: 0.45)
    static let verdeScuro = Color(red: 0.05, green: 0.35, blue: 0.15)
    static let ciano = Color(red: 0.35, green: 0.95, blue: 1.0)
    static let ambra = Color(red: 1.0, green: 0.72, blue: 0.2)
    static let rosso = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let sfondo = Color(red: 0.01, green: 0.035, blue: 0.02)
    static let pannello = Color(red: 0.03, green: 0.08, blue: 0.05)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    /// Bagliore fosforescente tipico dei monitor CRT.
    func bagliore(_ colore: Color = Tema.verde, raggio: CGFloat = 4) -> some View {
        shadow(color: colore.opacity(0.7), radius: raggio)
    }

    /// Pannello con bordo verde sottile.
    func pannello(_ colore: Color = Tema.verde) -> some View {
        padding(12)
            .background(Tema.pannello)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(colore.opacity(0.45), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

/// Titolo di sezione in stile "[ TITOLO ]".
struct TitoloSezione: View {
    let testo: String
    var colore: Color = Tema.verde
    var body: some View {
        HStack(spacing: 8) {
            Text("[ \(testo) ]").font(Tema.mono(13, .bold)).foregroundColor(colore).bagliore(colore)
            Rectangle().fill(colore.opacity(0.35)).frame(height: 1)
        }
    }
}

struct TastoTerminale: ButtonStyle {
    var colore: Color = Tema.verde
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tema.mono(13, .medium))
            .foregroundColor(configuration.isPressed ? .black : colore)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(configuration.isPressed ? colore : colore.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(colore.opacity(0.6)))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// Scanline, vignettatura e leggero sfarfallio stile monitor CRT.
struct EffettoCRT: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Canvas { g, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        g.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.28)))
                        y += 3
                    }
                    // banda luminosa che scorre lentamente
                    let banda = CGFloat((t * 60).truncatingRemainder(dividingBy: Double(size.height + 200))) - 100
                    g.fill(Path(CGRect(x: 0, y: banda, width: size.width, height: 80)),
                           with: .linearGradient(Gradient(colors: [.clear, Tema.verde.opacity(0.035), .clear]),
                                                 startPoint: CGPoint(x: 0, y: banda), endPoint: CGPoint(x: 0, y: banda + 80)))
                }
                RadialGradient(colors: [.clear, .black.opacity(0.65)], center: .center, startRadius: 180, endRadius: 560)
                Color.white.opacity(sin(t * 37) > 0.96 ? 0.025 : 0)
            }
        }
    }
}
