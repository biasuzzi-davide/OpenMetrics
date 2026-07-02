import SwiftUI
import ServiceManagement

struct SettingsTab: View {
    var store: MetricsStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DetailSection(title: "Barra menu") {
                    Toggle("CPU", isOn: $settings.showCPUInMenuBar)
                    Toggle("RAM", isOn: $settings.showRAMInMenuBar)
                    Toggle("Disco", isOn: $settings.showDiskInMenuBar)
                    Toggle("Batteria", isOn: $settings.showBatteryInMenuBar)
                    Toggle("Rete", isOn: $settings.showNetworkInMenuBar)
                    Toggle("Claude", isOn: $settings.showClaudeInMenuBar)
                    Toggle("Codex", isOn: $settings.showCodexInMenuBar)
                }

                DetailSection(title: "AI") {
                    Picker("Usage", selection: $settings.aiUsageDisplayMode) {
                        ForEach(AIUsageDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Reset", selection: $settings.aiResetDisplayMode) {
                        ForEach(AIResetDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                DetailSection(title: "Aggiornamento") {
                    Picker("Intervallo", selection: $settings.refreshInterval) {
                        Text("1s").tag(1)
                        Text("2s").tag(2)
                        Text("5s").tag(5)
                        Text("10s").tag(10)
                    }
                    .pickerStyle(.segmented)

                    Text("Intervalli piu alti consumano meno batteria.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DetailSection(title: "Avvio") {
                    Toggle("Avvio automatico", isOn: $settings.launchAtLogin)
                }
            }
            .padding(.trailing, 6)
        }
        .onChange(of: settings.refreshInterval) { value in
            store.setRefreshInterval(value)
        }
        .onAppear {
            settings.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
        .onChange(of: settings.launchAtLogin) { newValue in
            Task {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    settings.launchAtLogin = false
                }
            }
        }
    }
}
