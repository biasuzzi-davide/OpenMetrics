import SwiftUI

struct DetailsTab: View {
    var snapshot: SystemSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InfoSection(title: "Sistema", rows: [
                    .init("macOS", snapshot.osVersion),
                    .init("Host", snapshot.hostName),
                    .init("Risparmio energia", snapshot.lowPowerModeEnabled ? "Attivo" : "Disattivo"),
                    .init("Stato termico", MetricsFormatter.thermal(snapshot.thermalState))
                ])

                InfoSection(title: "CPU", rows: [
                    .init("Utilizzo", MetricsFormatter.percent(snapshot.cpuUsage)),
                    .init("Core", "\(snapshot.activeProcessorCount) attivi / \(snapshot.processorCount) totali"),
                    .init("Load average", MetricsFormatter.loadAverage(snapshot.loadAverage))
                ])

                InfoSection(title: "Memoria", rows: [
                    .init("Usata", MetricsFormatter.bytes(snapshot.memoryUsed)),
                    .init("Libera", MetricsFormatter.bytes(snapshot.memoryFree)),
                    .init("Cache", MetricsFormatter.bytes(snapshot.memoryCached)),
                    .init("Wired", MetricsFormatter.bytes(snapshot.memoryWired)),
                    .init("Compressa", MetricsFormatter.bytes(snapshot.memoryCompressed)),
                    .init("Swap", "\(MetricsFormatter.bytes(snapshot.swapUsed)) / \(MetricsFormatter.bytes(snapshot.swapTotal))")
                ])

                InfoSection(title: "Disco e rete", rows: [
                    .init("Disco usato", MetricsFormatter.bytes(snapshot.diskUsed)),
                    .init("Disco libero", MetricsFormatter.bytes(snapshot.diskAvailable)),
                    .init("Interfaccia", snapshot.networkInterface ?? "n/d"),
                    .init("IP", snapshot.ipAddress ?? "n/d")
                ])

                if !snapshot.componentTemperatures.isEmpty {
                    InfoSection(
                        title: "Temperature",
                        rows: snapshot.componentTemperatures.keys.sorted().compactMap { component in
                            snapshot.componentTemperatures[component].map {
                                InfoSection.Row(component, MetricsFormatter.temperature($0))
                            }
                        }
                    )
                }
            }
            .padding(.bottom, 2)
        }
    }
}

/// Gruppo di righe etichetta/valore con titolo, come le sezioni di Impostazioni di Sistema.
struct InfoSection: View {
    struct Row {
        var title: String
        var value: String

        init(_ title: String, _ value: String) {
            self.title = title
            self.value = value
        }
    }

    var title: String
    var rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    if index > 0 {
                        Divider().padding(.leading, 12)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text(rows[index].title)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Text(rows[index].value)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
            }
            .tile(cornerRadius: 14)
        }
    }
}
