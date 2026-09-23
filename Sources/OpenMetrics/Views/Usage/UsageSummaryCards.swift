import SwiftUI

struct UsageSummaryCards: View {
    var analysis: UsageAnalysis
    var granularity: UsageGranularity

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 10)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            UsageStatCard(
                icon: "number",
                title: "Token totali",
                value: UsageFormatter.tokens(analysis.totals.totalTokens),
                detail: "\(UsageFormatter.integer(analysis.totals.requests)) richieste"
            )

            UsageStatCard(
                icon: "creditcard",
                title: "Costo equivalente",
                value: UsageFormatter.dollars(analysis.totals.costUSD),
                detail: analysis.totals.hasUnpriced ? "esclude modelli senza tariffa" : "stima tariffe API",
                isWarning: analysis.totals.hasUnpriced
            )

            UsageStatCard(
                icon: "calendar",
                title: "Media giornaliera",
                value: UsageFormatter.dollars(analysis.averageCostPerActiveDay),
                detail: "\(UsageFormatter.tokens(Int(analysis.averageTokensPerActiveDay))) token su \(analysis.activeDays) gg attivi"
            )

            UsageStatCard(
                icon: "arrow.down.circle",
                title: "Quota da cache",
                value: UsageFormatter.percent(analysis.totals.cacheHitRatio),
                detail: "\(UsageFormatter.tokens(analysis.totals.cacheReadTokens)) letti da cache"
            )

            UsageStatCard(
                icon: "arrow.up.circle",
                title: "Output",
                value: UsageFormatter.tokens(analysis.totals.outputTokens),
                detail: "input \(UsageFormatter.tokens(analysis.totals.inputTokens))"
            )

            if let peak = analysis.busiestBucket {
                UsageStatCard(
                    icon: "flame",
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
    var title: String
    var value: String
    var detail: String
    var isWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(.title2, design: .monospaced).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(isWarning ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
