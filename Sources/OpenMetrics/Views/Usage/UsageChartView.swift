import Charts
import SwiftUI

struct UsageChartView: View {
    var analysis: UsageAnalysis
    var filter: UsageFilter

    @State private var hovered: Date?

    private var palette: [Color] {
        [.accentColor, .teal, .orange, .purple, .pink, .green, .indigo, .yellow, .red, .mint, .brown, .cyan]
    }

    /// Lo stack per tipo di token ha colori fissi, cosi il grafico resta leggibile tra un filtro e l'altro.
    private var colorRange: [Color] {
        guard filter.stack != .component else {
            return analysis.seriesOrder.map { title in
                switch title {
                case UsageComponent.input.title: return .accentColor
                case UsageComponent.output.title: return .orange
                case UsageComponent.cacheWrite.title: return .purple
                default: return .teal
                }
            }
        }
        return analysis.seriesOrder.enumerated().map { palette[$0.offset % palette.count] }
    }

    private var hoveredBucket: UsageBucket? {
        guard let hovered else { return nil }
        return analysis.buckets.first { $0.start == hovered }
    }

    private var hoveredSeries: [UsageSeriesPoint] {
        guard let hovered else { return [] }
        let points = analysis.seriesPoints.filter { $0.bucketStart == hovered }
        return analysis.seriesOrder.compactMap { name in points.first { $0.series == name } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            Chart(analysis.seriesPoints) { point in
                BarMark(
                    x: .value("Periodo", point.bucketStart, unit: filter.granularity.calendarComponent),
                    y: .value(filter.metric.title, point.value)
                )
                .foregroundStyle(by: .value("Serie", point.series))
                .opacity(hovered == nil || hovered == point.bucketStart ? 1 : 0.35)
            }
            .chartForegroundStyleScale(domain: analysis.seriesOrder, range: colorRange)
            .chartLegend(position: .bottom, spacing: 8)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let raw = value.as(Double.self) {
                            Text(UsageFormatter.axisValue(raw, metric: filter.metric))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hovered = bucket(at: location, proxy: proxy, geometry: geometry)
                            case .ended:
                                hovered = nil
                            }
                        }
                }
            }
            .frame(minHeight: 220)
            .overlay(alignment: .topTrailing) { tooltip }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(filter.metric.title)
                .font(.headline)
            Text("per \(filter.granularity.title.lowercased()), diviso per \(filter.stack.title.lowercased())")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if analysis.buckets.isEmpty {
                Text("nessun dato nel periodo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var tooltip: some View {
        if let bucket = hoveredBucket {
            VStack(alignment: .leading, spacing: 4) {
                Text(UsageFormatter.bucketLabel(bucket.start, granularity: filter.granularity))
                    .font(.caption.weight(.semibold))

                ForEach(hoveredSeries) { point in
                    HStack(spacing: 6) {
                        Text(point.series)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 10)
                        Text(UsageFormatter.axisValue(point.value, metric: filter.metric))
                            .font(.system(.caption2, design: .monospaced))
                    }
                    .font(.caption2)
                }

                Divider()

                HStack(spacing: 6) {
                    Text("Totale")
                    Spacer(minLength: 10)
                    Text(UsageFormatter.metricValue(bucket.totals, metric: filter.metric))
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                }
                .font(.caption2)
            }
            .padding(8)
            .frame(maxWidth: 230)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(8)
            .allowsHitTesting(false)
        }
    }

    /// Converte la posizione del cursore nel bucket sotto di esso.
    private func bucket(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> Date? {
        guard let plotFrame = proxy.plotAreaFrameAnchorIfAvailable else { return nil }
        let origin = geometry[plotFrame].origin
        guard let date: Date = proxy.value(atX: location.x - origin.x) else { return nil }

        let target = UsageAnalyzer.bucket(for: date, granularity: filter.granularity)
        return analysis.buckets.contains { $0.start == target } ? target : nil
    }
}

private extension ChartProxy {
    /// `plotAreaFrame` e stato rinominato in `plotFrame` su macOS 14: qui serve il nome che
    /// funziona anche su macOS 13.
    var plotAreaFrameAnchorIfAvailable: Anchor<CGRect>? {
        plotAreaFrame
    }
}
