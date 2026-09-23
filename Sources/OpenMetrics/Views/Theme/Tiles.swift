import SwiftUI

/// Modulo "frosted" sopra il vetro del pannello: riempimento leggero e bordo luminoso in alto,
/// come i moduli di Centro di Controllo.
private struct TileModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark

        content.background {
            shape
                .fill(.primary.opacity(isDark ? 0.065 : 0.045))
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(isDark ? 0.14 : 0.8),
                                .white.opacity(isDark ? 0.03 : 0.25)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                }
        }
    }
}

extension View {
    func tile(cornerRadius: CGFloat = 16) -> some View {
        modifier(TileModifier(cornerRadius: cornerRadius))
    }
}

/// Etichetta di un modulo: simbolo monocromo e titolo in maiuscoletto.
struct TileLabel: View {
    var title: String
    var symbol: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

/// Numero grande con unita piu piccola, cifre tabulari e transizione numerica.
struct BigValue: View {
    var number: String
    var unit: String? = nil
    var size: CGFloat = 28

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(number)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
            if let unit {
                Text(unit)
                    .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .animation(.easeOut(duration: 0.3), value: number)
    }
}

/// Anello di capacita con estremi arrotondati.
struct RingGauge: View {
    var value: Double
    var tint: Color
    var lineWidth: CGFloat = 5

    var body: some View {
        let clamped = min(max(value, 0), 1)

        ZStack {
            Circle()
                .stroke(.primary.opacity(0.09), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: clamped)
    }
}

struct SparklineSeries: Identifiable {
    var id: String
    var values: [Double]
    var tint: Color
}

enum SparklineRange {
    /// Scala fissa, per confrontare il livello assoluto.
    case fixed(ClosedRange<Double>)
    /// Scala sui dati, per vedere il movimento; `floor` blocca il minimo (0 per i tassi).
    case adaptive(floor: Double? = nil)
}

/// Mini grafico ad area senza assi: racconta l'andamento recente, non i valori esatti.
/// Disegnato con `Path` invece di Swift Charts: dentro il pannello si aggiorna ogni secondo
/// e non deve costare nulla.
struct Sparkline: View {
    var series: [SparklineSeries]
    var range: SparklineRange = .adaptive()
    var capacity: Int = MetricHistory.capacity

    /// Un quarto di margine sopra e sotto: la linea respira senza toccare i bordi.
    private var domain: ClosedRange<Double> {
        switch range {
        case .fixed(let fixed):
            return fixed
        case .adaptive(let floor):
            let values = series.flatMap(\.values)
            guard let low = values.min(), let high = values.max() else { return 0...1 }
            var span = high - min(low, floor ?? low)
            if span < 1e-9 {
                span = max(abs(high) * 0.1, 0.01)
            }
            let pad = span * 0.25
            let lower = floor ?? max(0, low - pad)
            return lower...(high + pad)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let domain = domain

            ZStack {
                ForEach(series) { line in
                    let points = Self.points(for: line.values, capacity: capacity, domain: domain, in: size)

                    if points.count > 1 {
                        Self.areaPath(through: points, height: size.height)
                            .fill(
                                LinearGradient(
                                    colors: [line.tint.opacity(0.32), line.tint.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Self.linePath(through: points)
                            .stroke(line.tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// I campioni sono allineati a destra: la linea cresce da destra finche la storia non e piena.
    private static func points(for values: [Double], capacity: Int, domain: ClosedRange<Double>, in size: CGSize) -> [CGPoint] {
        let span = domain.upperBound - domain.lowerBound
        guard capacity > 1, span > 0 else { return [] }
        let offset = capacity - values.count
        let step = size.width / CGFloat(capacity - 1)
        let inset: CGFloat = 1

        return values.enumerated().map { index, value in
            let fraction = min(max((value - domain.lowerBound) / span, 0), 1)
            let y = inset + (size.height - inset * 2) * (1 - CGFloat(fraction))
            return CGPoint(x: CGFloat(index + offset) * step, y: y)
        }
    }

    /// Curva morbida passando per i punti medi: niente sbalzi fuori dai dati.
    private static func linePath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        guard points.count > 2 else {
            points.dropFirst().forEach { path.addLine(to: $0) }
            return path
        }

        for index in 1..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let middle = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.addQuadCurve(to: middle, control: current)
        }
        path.addLine(to: points[points.count - 1])
        return path
    }

    private static func areaPath(through points: [CGPoint], height: CGFloat) -> Path {
        var path = linePath(through: points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.addLine(to: CGPoint(x: first.x, y: height))
        path.closeSubpath()
        return path
    }
}
