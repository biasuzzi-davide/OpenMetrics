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
                    HStack(spacing: 4) {
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
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.snapshot.providers) { provider in
                        AIProviderCard(
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

private struct AIProviderCard: View {
    var provider: AIProviderUsage
    var isRefreshing: Bool
    var usageMode: AIUsageDisplayMode
    var resetMode: AIResetDisplayMode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AIProviderBadge(provider: provider.id)

                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.id.rawValue)
                        .font(.body.weight(.semibold))
                    if let plan = provider.plan {
                        Text(plan)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                AIStatusPill(status: provider.status, isRefreshing: isRefreshing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)

            if case .loading = provider.status {
                Divider().padding(.leading, 10)
                ProgressView()
                    .controlSize(.small)
                    .padding(10)
            } else if provider.metrics.isEmpty {
                Divider().padding(.leading, 10)
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
            } else {
                ForEach(provider.metrics) { metric in
                    Divider().padding(.leading, 10)
                    MetricRow(
                        icon: metric.icon,
                        title: metric.title,
                        value: metric.displayValue(usageMode: usageMode),
                        detail: metric.displayDetail(resetMode: resetMode),
                        progress: metric.displayProgress(usageMode: usageMode),
                        tint: MetricTint.usage(metric.usedFraction, base: MetricTint.provider(provider.id))
                    )
                }
            }
        }
        .card(.panel)
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
