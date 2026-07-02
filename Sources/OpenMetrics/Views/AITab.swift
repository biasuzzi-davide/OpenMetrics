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
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("AI", systemImage: "sparkles")
                        .font(.headline)

                    Spacer()

                    if let updatedAt = store.snapshot.updatedAt {
                        Text(updatedAt, style: .time)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        store.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isRefreshing)
                    .help("Aggiorna AI")
                }

                ForEach(store.snapshot.providers) { provider in
                    AIProviderPanel(
                        provider: provider,
                        isRefreshing: store.isRefreshing,
                        usageMode: usageMode,
                        resetMode: resetMode
                    )
                }
            }
            .padding(.trailing, 6)
        }
    }
}

private struct AIProviderPanel: View {
    var provider: AIProviderUsage
    var isRefreshing: Bool
    var usageMode: AIUsageDisplayMode
    var resetMode: AIResetDisplayMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AIProviderIcon(provider: provider.id, size: 18)

                Text(provider.id.rawValue)
                    .font(.headline)

                if let plan = provider.plan {
                    Text(plan)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusLabel
            }

            if case .loading = provider.status {
                ProgressView()
                    .controlSize(.small)
            } else if provider.metrics.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(provider.metrics) { metric in
                        AIMetricLine(metric: metric, usageMode: usageMode, resetMode: resetMode)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch provider.status {
        case .idle:
            Text("n/d")
                .foregroundStyle(.secondary)
        case .loading:
            Text("lettura")
                .foregroundStyle(.secondary)
        case .available:
            if isRefreshing {
                Text("refresh")
                    .foregroundStyle(.secondary)
            } else {
                Text("ok")
                    .foregroundStyle(.green)
            }
        case .missingCredentials:
            Text("login")
                .foregroundStyle(.orange)
        case .failed:
            Text("errore")
                .foregroundStyle(.red)
        }
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

private struct AIMetricLine: View {
    var metric: AIUsageMetric
    var usageMode: AIUsageDisplayMode
    var resetMode: AIResetDisplayMode

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)

                Text(metric.title)

                Spacer(minLength: 10)

                Text(metric.displayValue(usageMode: usageMode))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if let progress = metric.displayProgress(usageMode: usageMode) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }

            Text(metric.displayDetail(resetMode: resetMode))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
