import SwiftUI

struct OverviewTab: View {
    var snapshot: SystemSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 0) {
                    MetricRow(
                        icon: "cpu",
                        title: "CPU",
                        value: MetricsFormatter.percent(snapshot.cpuUsage),
                        detail: "\(snapshot.activeProcessorCount)/\(snapshot.processorCount) core attivi · load \(MetricsFormatter.loadAverage(snapshot.loadAverage))",
                        progress: snapshot.cpuUsage,
                        tint: MetricTint.usage(snapshot.cpuUsage, base: MetricTint.cpu)
                    )

                    InsetDivider()

                    MetricRow(
                        icon: "memorychip",
                        title: "RAM",
                        value: MetricsFormatter.percent(snapshot.memoryUsage),
                        detail: "\(MetricsFormatter.bytes(snapshot.memoryUsed)) su \(MetricsFormatter.bytes(snapshot.memoryTotal))",
                        progress: snapshot.memoryUsage,
                        tint: MetricTint.usage(snapshot.memoryUsage, base: MetricTint.memory)
                    )

                    InsetDivider()

                    MetricRow(
                        icon: "internaldrive",
                        title: "Disco",
                        value: MetricsFormatter.percent(snapshot.diskUsage),
                        detail: "\(MetricsFormatter.bytes(snapshot.diskAvailable)) liberi",
                        progress: snapshot.diskUsage,
                        tint: MetricTint.usage(snapshot.diskUsage, base: MetricTint.disk, warning: 0.9, critical: 0.97)
                    )

                    if let batteryPercent = snapshot.batteryPercent {
                        let charging = snapshot.batteryIsCharging == true

                        InsetDivider()

                        MetricRow(
                            icon: charging ? "battery.100.bolt" : "battery.100",
                            title: "Batteria",
                            value: MetricsFormatter.percent(batteryPercent),
                            detail: batteryDetail(snapshot, charging: charging),
                            progress: batteryPercent,
                            tint: MetricTint.battery(batteryPercent, charging: charging)
                        )
                    }
                }
                .card(.panel)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    MiniMetric(icon: "arrow.down", title: "Rete in", value: MetricsFormatter.rate(snapshot.networkInPerSecond), tint: MetricTint.networkIn)
                    MiniMetric(icon: "arrow.up", title: "Rete out", value: MetricsFormatter.rate(snapshot.networkOutPerSecond), tint: MetricTint.networkOut)
                    MiniMetric(icon: "thermometer.medium", title: "Termico", value: MetricsFormatter.thermal(snapshot.thermalState), tint: MetricTint.thermal(snapshot.thermalState))
                    MiniMetric(icon: "clock", title: "Uptime", value: MetricsFormatter.duration(snapshot.uptime), tint: MetricTint.uptime)

                    ForEach(snapshot.componentTemperatures.keys.sorted(), id: \.self) { component in
                        if let temperature = snapshot.componentTemperatures[component] {
                            MiniMetric(icon: "thermometer", title: component, value: MetricsFormatter.temperature(temperature), tint: MetricTint.temperature)
                        }
                    }
                }
            }
            .padding(.bottom, 2)
        }
    }

    private func batteryDetail(_ snapshot: SystemSnapshot, charging: Bool) -> String {
        let status = charging ? "In carica" : "Non in carica"
        return "\(status) · \(MetricsFormatter.minutes(snapshot.batteryTimeRemainingMinutes))"
    }
}
