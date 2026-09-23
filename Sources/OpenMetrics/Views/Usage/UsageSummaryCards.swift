import SwiftUI

struct UsageSummaryCards: View {
    var analysis: UsageAnalysis
    var granularity: UsageGranularity

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            UsageStatCard(
                icon: "number",
                tint: .blue,
                title: "Token totali",
                value: UsageFormatter.tokens(analysis.totals.totalTokens),
                detail: "\(UsageFormatter.integer(analysis.totals.requests)) richieste"
            )

            UsageStatCard(
                icon: "creditcard",
                tint: analysis.totals.hasUnpriced ? .orange : .green,
                title: "Costo equivalente",
                value: UsageFormatter.dollars(analysis.totals.costUSD),
                detail: analysis.totals.hasUnpriced ? "esclude modelli senza tariffa" : "stima a tariffe API",
                isWarning: analysis.totals.hasUnpriced
            )

            UsageStatCard(
                icon: "calendar",
                tint: .purple,
                title: "Media giornaliera",
                value: UsageFormatter.dollars(analysis.averageCostPerActiveDay),
                detail: "\(UsageFormatter.tokens(Int(analysis.averageTokensPerActiveDay))) token su \(analysis.activeDays) gg attivi"
            )

            UsageStatCard(
                icon: "arrow.down.circle",
                tint: .teal,
                title: "Quota da cache",
                value: UsageFormatter.percent(analysis.totals.cacheHitRatio),
                detail: "\(UsageFormatter.tokens(analysis.totals.cacheReadTokens)) letti da cache"
            )

            UsageStatCard(
                icon: "arrow.up.circle",
                tint: .indigo,
                title: "Output",
                value: UsageFormatter.tokens(analysis.totals.outputTokens),
                detail: "input \(UsageFormatter.tokens(analysis.totals.inputTokens))"
            )

            if let peak = analysis.busiestBucket {
                UsageStatCard(
                    icon: "flame",
                    tint: .red,
                    title: "Picco",
                    value: UsageFormatter.tokens(peak.totals.totalTokens),
                    detail: UsageFormatter.bucketLabel(peak.start, granularity: granularity)
                )
            }
        }
    }
}

struct UsageStatCard: View {
    var icon: String
    var tint: Color
    var title: String
    var value: String
    var detail: String
    var isWarning = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconBadge(systemName: icon, tint: tint, size: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(value)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(isWarning ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .animation(.easeOut(duration: 0.3), value: value)
    }
}
