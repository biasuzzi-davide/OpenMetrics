import AppKit
import SwiftUI

enum PanelTab: String, CaseIterable, Identifiable {
    case overview = "Panoramica"
    case ai = "AI"
    case details = "Dettagli"

    var id: String { rawValue }
}

struct MetricsPanel: View {
    @ObservedObject var store: MetricsStore
    @ObservedObject var aiStore: AIUsageStore
    @ObservedObject var settings: AppSettings
    @State private var tab = PanelTab.overview

    var body: some View {
        let snapshot = store.snapshot

        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(snapshot: snapshot, store: store, aiStore: aiStore)

            Picker("Sezione", selection: $tab) {
                ForEach(PanelTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ZStack {
                Group {
                    switch tab {
                    case .overview:
                        OverviewTab(snapshot: snapshot, history: store.history)
                    case .ai:
                        AITab(store: aiStore, settings: settings)
                    case .details:
                        DetailsTab(snapshot: snapshot)
                    }
                }
                .id(tab)
                .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.easeInOut(duration: 0.18), value: tab)
        }
        .padding(16)
        .frame(width: 380, height: 540)
        .background { PanelBackdrop() }
        .onAppear {
            store.setRefreshInterval(settings.refreshInterval)
        }
        .onChange(of: settings.refreshInterval) { value in
            store.setRefreshInterval(value)
        }
    }
}

/// Intestazione minima: chi e la macchina, quando e stato letto l'ultimo campione, e il
/// menu con le azioni che prima occupavano un footer intero.
private struct PanelHeader: View {
    var snapshot: SystemSnapshot
    var store: MetricsStore
    var aiStore: AIUsageStore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.hostName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Text("OpenMetrics · aggiornato")
                    Text(snapshot.updatedAt, style: .time)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            PanelMenu(store: store, aiStore: aiStore)
        }
    }
}

private struct PanelMenu: View {
    var store: MetricsStore
    var aiStore: AIUsageStore

    var body: some View {
        Menu {
            Button {
                store.refresh()
                aiStore.refresh()
            } label: {
                Label("Aggiorna", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r")

            Button {
                UsageWindowController.shared.show()
            } label: {
                Label("Storico utilizzo AI…", systemImage: "chart.bar.xaxis")
            }

            Divider()

            OpenSettingsButton()

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Esci da OpenMetrics", systemImage: "power")
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Azioni")
    }
}

/// Apre la finestra Impostazioni (⌘,).
struct OpenSettingsButton: View {
    var body: some View {
        Button {
            SettingsWindow.open()
        } label: {
            Label("Impostazioni…", systemImage: "gearshape")
        }
        .keyboardShortcut(",")
    }
}

enum SettingsWindow {
    /// Usa la stessa azione AppKit della voce "Impostazioni…" del menu app: l'azione
    /// SwiftUI `openSettings` viene ignorata quando l'app e un accessorio senza
    /// finestre attive, mentre il selettore passa sempre dalla catena dei responder.
    @MainActor
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
