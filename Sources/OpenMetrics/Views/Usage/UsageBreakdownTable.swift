import SwiftUI

/// Tabella ordinabile usata sia per i modelli sia per i progetti.
struct UsageBreakdownTable: View {
    var rows: [UsageBreakdownRow]
    var grandTotal: UsageTotals
    var labelColumn: String
    var showsProvider: Bool
    var pricing: PricingTable

    @State private var sortOrder = [KeyPathComparator(\UsageBreakdownRow.totals.totalTokens, order: .reverse)]

    private var sorted: [UsageBreakdownRow] {
        rows.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sorted, sortOrder: $sortOrder) {
            TableColumn(labelColumn) { row in
                HStack(spacing: 6) {
                    if showsProvider, let provider = row.provider {
                        AIProviderBadge(provider: provider, size: 16)
                    }
                    Text(row.label)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(row.key)
                    if !pricing.hasPricing(for: row.key) && !showsProvider {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.orange)
                            .help("Nessuna tariffa configurata: il costo di questo modello non e conteggiato.")
                    }
                }
            }
            .width(min: 140, ideal: 220)

            TableColumn("Quota", value: \.totals.totalTokens) { row in
                UsageShareBar(
                    fraction: grandTotal.totalTokens > 0
                        ? Double(row.totals.totalTokens) / Double(grandTotal.totalTokens)
                        : 0,
                    tint: row.provider.map(MetricTint.provider) ?? .accentColor
                )
            }
            .width(min: 70, ideal: 90)

            TableColumn("Token", value: \.totals.totalTokens) { row in
                numeric(UsageFormatter.tokens(row.totals.totalTokens))
            }
            .width(min: 60, ideal: 70)

            TableColumn("Input", value: \.totals.inputTokens) { row in
                numeric(UsageFormatter.tokens(row.totals.inputTokens))
            }
            .width(min: 60, ideal: 70)

            TableColumn("Output", value: \.totals.outputTokens) { row in
                numeric(UsageFormatter.tokens(row.totals.outputTokens))
            }
            .width(min: 60, ideal: 70)

            TableColumn("Cache R", value: \.totals.cacheReadTokens) { row in
                numeric(UsageFormatter.tokens(row.totals.cacheReadTokens))
            }
            .width(min: 60, ideal: 70)

            TableColumn("Richieste", value: \.totals.requests) { row in
                numeric(UsageFormatter.integer(row.totals.requests))
            }
            .width(min: 60, ideal: 80)

            TableColumn("Costo", value: \.totals.costUSD) { row in
                numeric(row.totals.hasUnpriced && row.totals.costUSD == 0 ? "n/d" : UsageFormatter.dollars(row.totals.costUSD))
            }
            .width(min: 60, ideal: 80)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func numeric(_ text: String) -> some View {
        Text(text)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct UsageShareBar: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            CapacityBar(fraction: fraction, tint: tint, height: 6)

            Text(UsageFormatter.percent(fraction))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }
}
