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
    @AppStorage(SettingsKey.launchAtLogin) private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DetailSection(title: "Barra menu") {
                Toggle("CPU", isOn: $showCPU)
                Toggle("RAM", isOn: $showRAM)
                Toggle("Disco", isOn: $showDisk)
                Toggle("Batteria", isOn: $showBattery)
                Toggle("Rete", isOn: $showNetwork)
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

            Spacer()
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
