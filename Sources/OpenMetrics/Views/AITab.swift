import SwiftUI

struct AITab: View {
    @ObservedObject var store: AIUsageStore
    @ObservedObject var settings: AppSettings

    private var usageMode: AIUsageDisplayMode {
        AIUsageDisplayMode(rawValue: settings.aiUsageDisplayMode) ?? .used
    }

    private var resetMode: AIResetDisplayMode {
        AIResetDisplayMode(rawValue: settings.aiResetDisplayMode) ?? .relative
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let updatedAt = store.snapshot.updatedAt {
                    HStack(spacing: 3) {
                        Text("letto")
                        Text(updatedAt, style: .time)
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                        .animation(
                            store.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: store.isRefreshing
                        )
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing)
                .help("Rilegge i limiti di Claude e Codex")

                Button {
                    UsageWindowController.shared.show()
                } label: {
                    Label("Storico", systemImage: "chart.bar.xaxis")
                }
                .controlSize(.small)
                .help("Apri lo storico di utilizzo")
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.snapshot.providers) { provider in
                        ProviderTile(
                            provider: provider,
                            isRefreshing: store.isRefreshing,
                            usageMode: usageMode,
                            resetMode: resetMode
                        )
                    }
                }
                .padding(.bottom, 2)
            }
        }
    }
}

/// Un provider per modulo: anelli per le quote, barre per il denaro, celle per il resto.
private struct ProviderTile: View {
    var provider: AIProviderUsage
    var isRefreshing: Bool
    var usageMode: AIUsageDisplayMode
    var resetMode: AIResetDisplayMode

    private var rings: [AIUsageMetric] { provider.metrics.filter { $0.usedFraction != nil } }
    private var bars: [AIUsageMetric] { provider.metrics.filter { $0.usedFraction == nil && $0.progress != nil } }
    private var stats: [AIUsageMetric] { provider.metrics.filter { $0.usedFraction == nil && $0.progress == nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AIProviderBadge(provider: provider.id, size: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.id.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    if let plan = provider.plan {
                        Text(plan)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                AIStatusPill(status: provider.status, isRefreshing: isRefreshing)
            }

            if case .loading = provider.status {
                ProgressView()
                    .controlSize(.small)
            } else if provider.metrics.isEmpty {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                if !rings.isEmpty || !stats.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                        ForEach(rings) { metric in
                            RingCell(
                                metric: metric,
                                usageMode: usageMode,
                                resetMode: resetMode,
                                tint: MetricTint.usage(metric.usedFraction, base: MetricTint.provider(provider.id))
                            )
                        }
                        ForEach(stats) { metric in
                            StatCell(metric: metric)
                        }
                    }
                }

                ForEach(bars) { metric in
                    BarRow(metric: metric, tint: MetricTint.usage(metric.progress, base: MetricTint.provider(provider.id)))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tile()
    }

    private var emptyText: String {
        switch provider.status {
        case .missingCredentials:
            return "Credenziali locali non trovate."
        case .failed(let message):
            return message
        default:
            return "Nessun dato."
        }
    }
}

private struct RingCell: View {
    var metric: AIUsageMetric
    var usageMode: AIUsageDisplayMode
    var resetMode: AIResetDisplayMode
    var tint: Color

    private var shown: Double {
        metric.displayProgress(usageMode: usageMode) ?? 0
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RingGauge(value: shown, tint: tint)
                Text(MetricsFormatter.percentDigits(shown))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 50, height: 50)

            Text(metric.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Group {
                if let reset = metric.menuBarReset(resetMode: resetMode) {
                    Label(reset, systemImage: "arrow.counterclockwise")
                } else {
                    Text(metric.detail)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.3), value: shown)
    }
}

private struct StatCell: View {
    var metric: AIUsageMetric

    var body: some View {
        VStack(spacing: 6) {
            Text(metric.value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: 50)

            Text(metric.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Text(metric.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BarRow: View {
    var metric: AIUsageMetric
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                TileLabel(title: metric.title, symbol: metric.icon)
                Spacer()
                Text(metric.value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
            }

            CapacityBar(fraction: metric.progress ?? 0, tint: tint)

            Text(metric.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Pallino colorato con stato: piu discreto di una parola colorata.
private struct AIStatusPill: View {
    var status: AIProviderStatus
    var isRefreshing: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var text: String {
        switch status {
        case .idle: return "n/d"
        case .loading: return "lettura"
        case .available: return isRefreshing ? "aggiorno" : "ok"
        case .missingCredentials: return "login"
        case .failed: return "errore"
        }
    }

    private var color: Color {
        switch status {
        case .idle, .loading: return .gray
        case .available: return isRefreshing ? .gray : .green
        case .missingCredentials: return .orange
        case .failed: return .red
        }
    }
}
