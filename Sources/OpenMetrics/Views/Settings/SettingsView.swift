import ServiceManagement
import SwiftUI

/// Finestra Impostazioni (⌘,) con le schede in toolbar, come le app di sistema.
struct SettingsView: View {
    var store: MetricsStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettingsPane(store: store, settings: settings)
                .frame(height: 300)
                .tabItem { Label("Generale", systemImage: "gearshape") }

            MenuBarSettingsPane(settings: settings)
                .frame(height: 470)
                .tabItem { Label("Barra menu", systemImage: "menubar.rectangle") }

            AISettingsPane(settings: settings)
                .frame(height: 210)
                .tabItem { Label("AI", systemImage: "sparkles") }
        }
        .frame(width: 480)
        .background(WindowLifecycle(onOpen: DockPolicy.windowDidAppear, onClose: DockPolicy.windowDidDisappear))
    }
}

private struct GeneralSettingsPane: View {
    var store: MetricsStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Intervallo di aggiornamento", selection: $settings.refreshInterval) {
                    Text("1 secondo").tag(1)
                    Text("2 secondi").tag(2)
                    Text("5 secondi").tag(5)
                    Text("10 secondi").tag(10)
                }
            } footer: {
                Text("Intervalli più alti consumano meno batteria.")
            }

            Section {
                Toggle("Avvia al login", isOn: $settings.launchAtLogin)
                Toggle("Mostra icona nel Dock", isOn: $settings.showDockIcon)
            } footer: {
                Text("Senza icona nel Dock l'app resta solo nella barra menu e ricompare quando apri una finestra.")
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .onChange(of: settings.refreshInterval) { value in
            store.setRefreshInterval(value)
        }
        .onChange(of: settings.showDockIcon) { value in
            DockPolicy.setPinned(value)
        }
        .onAppear {
            settings.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
        .onChange(of: settings.launchAtLogin) { newValue in
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

private struct MenuBarSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Sistema") {
                Toggle("CPU", isOn: $settings.showCPUInMenuBar)
                Toggle("RAM", isOn: $settings.showRAMInMenuBar)
                Toggle("Disco", isOn: $settings.showDiskInMenuBar)
                Toggle("Batteria", isOn: $settings.showBatteryInMenuBar)
                Toggle("Rete", isOn: $settings.showNetworkInMenuBar)
            }

            Section {
                Toggle("Claude", isOn: $settings.showClaudeInMenuBar)
                Toggle("Codex", isOn: $settings.showCodexInMenuBar)
            } header: {
                Text("AI")
            } footer: {
                Text("Con un provider AI attivo le metriche di sistema passano al formato compatto.")
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }
}

private struct AISettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Percentuale", selection: $settings.aiUsageDisplayMode) {
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
            } footer: {
                Text("Vale per il tab AI del pannello e per la barra menu.")
            }
        }
        .formStyle(.grouped)
    }
}
