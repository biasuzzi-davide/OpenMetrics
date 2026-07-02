import SwiftUI
import ServiceManagement

struct SettingsTab: View {
    var store: MetricsStore

    @AppStorage(SettingsKey.refreshInterval) private var refreshInterval = 1
    @AppStorage(SettingsKey.showCPUInMenuBar) private var showCPU = true
    @AppStorage(SettingsKey.showRAMInMenuBar) private var showRAM = true
    @AppStorage(SettingsKey.showDiskInMenuBar) private var showDisk = false
    @AppStorage(SettingsKey.showBatteryInMenuBar) private var showBattery = true
    @AppStorage(SettingsKey.showNetworkInMenuBar) private var showNetwork = false
    @AppStorage(SettingsKey.showClaudeInMenuBar) private var showClaude = false
    @AppStorage(SettingsKey.showCodexInMenuBar) private var showCodex = false
    @AppStorage(SettingsKey.aiUsageDisplayMode) private var aiUsageDisplayMode = AIUsageDisplayMode.used.rawValue
    @AppStorage(SettingsKey.aiResetDisplayMode) private var aiResetDisplayMode = AIResetDisplayMode.relative.rawValue
    @AppStorage(SettingsKey.launchAtLogin) private var launchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DetailSection(title: "Barra menu") {
                    Toggle("CPU", isOn: $showCPU)
                    Toggle("RAM", isOn: $showRAM)
                    Toggle("Disco", isOn: $showDisk)
                    Toggle("Batteria", isOn: $showBattery)
                    Toggle("Rete", isOn: $showNetwork)
                    Toggle("Claude", isOn: $showClaude)
                    Toggle("Codex", isOn: $showCodex)
                }

                DetailSection(title: "AI") {
                    Picker("Usage", selection: $aiUsageDisplayMode) {
                        ForEach(AIUsageDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Reset", selection: $aiResetDisplayMode) {
                        ForEach(AIResetDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                DetailSection(title: "Aggiornamento") {
                    Picker("Intervallo", selection: $refreshInterval) {
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
                    Toggle("Avvio automatico", isOn: $launchAtLogin)
                }
            }
            .padding(.trailing, 6)
        }
        .onChange(of: refreshInterval) { value in
            store.setRefreshInterval(value)
        }
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
        .onChange(of: launchAtLogin) { newValue in
            Task {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin = false
                }
            }
        }
    }
}
