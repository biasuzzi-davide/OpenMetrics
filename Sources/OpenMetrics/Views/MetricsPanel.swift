import SwiftUI

enum PanelTab: String, CaseIterable, Identifiable {
    case overview = "Panoramica"
    case ai = "AI"
    case details = "Dettagli"
    case settings = "Impostazioni"

    var id: String { rawValue }
}

struct MetricsPanel: View {
    @ObservedObject var store: MetricsStore
    @ObservedObject var aiStore: AIUsageStore
    @ObservedObject var settings: AppSettings
    @State private var tab = PanelTab.overview

    var body: some View {
        let snapshot = store.snapshot

        VStack(alignment: .leading, spacing: 14) {
            Header(snapshot: snapshot)

            Picker("", selection: $tab) {
                ForEach(PanelTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch tab {
                case .overview:
                    OverviewTab(snapshot: snapshot)
                case .details:
                    DetailsTab(snapshot: snapshot)
                case .ai:
                    AITab(store: aiStore, settings: settings)
                case .settings:
                    SettingsTab(store: store, settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Footer(store: store, snapshot: snapshot)
        }
        .onAppear {
            store.setRefreshInterval(settings.refreshInterval)
        }
        .onChange(of: settings.refreshInterval) { value in
            store.setRefreshInterval(value)
        }
    }
}

private struct Header: View {
    var snapshot: SystemSnapshot

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Label("OpenMetrics", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .font(.headline)
                Text(snapshot.hostName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(snapshot.updatedAt, style: .time)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Text("aggiornato")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
