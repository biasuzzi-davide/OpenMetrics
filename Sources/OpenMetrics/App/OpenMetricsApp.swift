import SwiftUI

@main
struct OpenMetricsApp: App {
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                Label("OpenMetrics", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .font(.headline)

                Text("Metriche di sistema")
                    .foregroundStyle(.secondary)

                Divider()

                Text("CPU e RAM saranno collegate al lettore nativo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 280)
        } label: {
            Label("OpenMetrics", systemImage: "gauge.with.dots.needle.bottom.50percent")
        }
        .menuBarExtraStyle(.window)
    }
}
