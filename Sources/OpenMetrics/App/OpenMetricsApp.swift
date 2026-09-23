import SwiftUI

@main
struct OpenMetricsApp: App {
    @NSApplicationDelegateAdaptor(OpenMetricsAppDelegate.self) private var appDelegate
    @StateObject private var store = MetricsStore()
    @StateObject private var aiStore = AIUsageStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        MenuBarExtra {
            MetricsPanel(store: store, aiStore: aiStore, settings: settings)
                .frame(width: 400, height: 560)
                .padding(16)
                .onAppear { DockPolicy.setPinned(settings.showDockIcon) }
                .onChange(of: settings.showDockIcon) { value in
                    DockPolicy.setPinned(value)
                }
        } label: {
            MenuBarLabel(snapshot: store.snapshot, aiSnapshot: aiStore.snapshot, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
