import SwiftUI

@main
struct OpenMetricsApp: App {
    @StateObject private var store = MetricsStore()

    var body: some Scene {
        MenuBarExtra {
            MetricsPanel(store: store)
                .frame(width: 380, height: 520)
                .padding(16)
        } label: {
            MenuBarLabel(snapshot: store.snapshot)
        }
        .menuBarExtraStyle(.window)
    }
}
