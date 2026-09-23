import Charts
import SwiftUI

struct UsageChartView: View {
    var analysis: UsageAnalysis
    var filter: UsageFilter

    @State private var hovered: Date?
    @State private var hoverX: CGFloat = 0
    @State private var chartWidth: CGFloat = 0

    private var palette: [Color] {
        [.blue, .teal, .orange, .purple, .pink, .green, .indigo, .yellow, .red, .mint, .brown, .cyan]
    }

    /// Tipi di token e provider hanno colori fissi, cosi il grafico resta leggibile tra un
    /// filtro e l'altro e coerente con il resto dell'app.
    private var colorRange: [Color] {
        switch filter.stack {
        case .component:
            return analysis.seriesOrder.map { title in
                switch title {
                case UsageComponent.input.title: return .blue
                case UsageComponent.output.title: return .orange
                case UsageComponent.cacheWrite.title: return .purple
                default: return .teal
                }
            }
        case .provider:
            return analysis.seriesOrder.enumerated().map { index, title in
                AIProviderID(rawValue: title).map(MetricTint.provider) ?? palette[index % palette.count]
            }
        case .model, .project:
            return analysis.seriesOrder.enumerated().map { palette[$0.offset % palette.count] }
        }
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

            Chart {
                if let hovered {
                    RectangleMark(x: .value("Periodo", hovered, unit: filter.granularity.calendarComponent))
                        .foregroundStyle(.primary.opacity(0.06))
                }

                ForEach(analysis.seriesPoints) { point in
                    BarMark(
                        x: .value("Periodo", point.bucketStart, unit: filter.granularity.calendarComponent),
                        y: .value(filter.metric.title, point.value)
                    )
                    .foregroundStyle(by: .value("Serie", point.series))
                    .cornerRadius(2.5)
                    .opacity(hovered == nil || hovered == point.bucketStart ? 1 : 0.45)
                }
            }
            .chartForegroundStyleScale(domain: analysis.seriesOrder, range: colorRange)
            .chartLegend(position: .bottom, spacing: 8)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine()
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let raw = value.as(Double.self) {
                            Text(UsageFormatter.axisValue(raw, metric: filter.metric))
                                .foregroundStyle(.secondary)
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
                                hoverX = location.x
                                chartWidth = geometry.size.width
                            case .ended:
                                hovered = nil
                            }
                        }
                }
            }
            .frame(minHeight: 220)
            .overlay(alignment: .topLeading) { tooltip }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(filter.metric.title)
                .font(.headline)
            Text("per \(filter.granularity.title.lowercased()), diviso per \(filter.stack.title.lowercased())")
                .font(.callout)
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
            .padding(10)
            .frame(width: Self.tooltipWidth)
            .glassSurface(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .offset(x: tooltipX, y: 6)
            .allowsHitTesting(false)
        }
    }

    private static let tooltipWidth: CGFloat = 220

    /// Segue il cursore restando dentro il grafico.
    private var tooltipX: CGFloat {
        let ideal = hoverX - Self.tooltipWidth / 2
        let maxX = max(chartWidth - Self.tooltipWidth - 4, 4)
        return min(max(ideal, 4), maxX)
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
