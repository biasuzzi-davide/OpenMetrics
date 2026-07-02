import SwiftUI

@main
struct OpenMetricsApp: App {
    @StateObject private var store = MetricsStore()
    @StateObject private var aiStore = AIUsageStore()

    var body: some Scene {
        MenuBarExtra {
            MetricsPanel(store: store, aiStore: aiStore)
                .frame(width: 400, height: 560)
                .padding(16)
        } label: {
            MenuBarLabel(snapshot: store.snapshot, aiSnapshot: aiStore.snapshot)
        }
        .menuBarExtraStyle(.window)
    }
}
