import SwiftUI

struct DetailsTab: View {
    var snapshot: SystemSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                DetailSection(title: "Sistema") {
                    InfoRow("macOS", snapshot.osVersion)
                    InfoRow("Host", snapshot.hostName)
                    InfoRow("Risparmio energia", snapshot.lowPowerModeEnabled ? "Attivo" : "Disattivo")
                    InfoRow("Stato termico", MetricsFormatter.thermal(snapshot.thermalState))
                }

                DetailSection(title: "CPU") {
                    InfoRow("Utilizzo", MetricsFormatter.percent(snapshot.cpuUsage))
                    InfoRow("Core", "\(snapshot.activeProcessorCount) attivi / \(snapshot.processorCount) totali")
                    InfoRow("Load average", MetricsFormatter.loadAverage(snapshot.loadAverage))
                }

                DetailSection(title: "Memoria") {
                    InfoRow("Usata", MetricsFormatter.bytes(snapshot.memoryUsed))
                    InfoRow("Libera", MetricsFormatter.bytes(snapshot.memoryFree))
                    InfoRow("Cache", MetricsFormatter.bytes(snapshot.memoryCached))
                    InfoRow("Wired", MetricsFormatter.bytes(snapshot.memoryWired))
                    InfoRow("Compressa", MetricsFormatter.bytes(snapshot.memoryCompressed))
                    InfoRow("Swap", "\(MetricsFormatter.bytes(snapshot.swapUsed)) / \(MetricsFormatter.bytes(snapshot.swapTotal))")
                }

                DetailSection(title: "Disco e rete") {
                    InfoRow("Disco usato", MetricsFormatter.bytes(snapshot.diskUsed))
                    InfoRow("Disco libero", MetricsFormatter.bytes(snapshot.diskAvailable))
                    InfoRow("Interfaccia", snapshot.networkInterface ?? "n/d")
                    InfoRow("IP", snapshot.ipAddress ?? "n/d")
                }

                if !snapshot.componentTemperatures.isEmpty {
                    DetailSection(title: "Temperature") {
                        ForEach(snapshot.componentTemperatures.keys.sorted(), id: \.self) { component in
                            if let temp = snapshot.componentTemperatures[component] {
                                InfoRow(component, MetricsFormatter.temperature(temp))
                            }
                        }
                    }
                }
            }
            .padding(.trailing, 6)
        }
    }
}
