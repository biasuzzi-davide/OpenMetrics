import SwiftUI

struct OverviewTab: View {
    var snapshot: SystemSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetricRow(
                icon: "cpu",
                title: "CPU",
                value: MetricsFormatter.percent(snapshot.cpuUsage),
                detail: "\(snapshot.activeProcessorCount)/\(snapshot.processorCount) core attivi - load \(MetricsFormatter.loadAverage(snapshot.loadAverage))",
                progress: snapshot.cpuUsage
            )

            MetricRow(
                icon: "memorychip",
                title: "RAM",
                value: MetricsFormatter.percent(snapshot.memoryUsage),
                detail: "\(MetricsFormatter.bytes(snapshot.memoryUsed)) / \(MetricsFormatter.bytes(snapshot.memoryTotal))",
                progress: snapshot.memoryUsage
            )

            MetricRow(
                icon: "internaldrive",
                title: "Disco",
                value: MetricsFormatter.percent(snapshot.diskUsage),
                detail: "\(MetricsFormatter.bytes(snapshot.diskAvailable)) liberi",
                progress: snapshot.diskUsage
            )

            if let batteryPercent = snapshot.batteryPercent {
                MetricRow(
                    icon: snapshot.batteryIsCharging == true ? "battery.100.bolt" : "battery.100",
                    title: "Batteria",
                    value: MetricsFormatter.percent(batteryPercent),
                    detail: batteryDetail(snapshot),
                    progress: batteryPercent
                )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MiniMetric(icon: "arrow.down", title: "Rete in", value: MetricsFormatter.rate(snapshot.networkInPerSecond))
                MiniMetric(icon: "arrow.up", title: "Rete out", value: MetricsFormatter.rate(snapshot.networkOutPerSecond))
                MiniMetric(icon: "thermometer.medium", title: "Termico", value: MetricsFormatter.thermal(snapshot.thermalState))
                MiniMetric(icon: "clock", title: "Uptime", value: MetricsFormatter.duration(snapshot.uptime))

                ForEach(snapshot.componentTemperatures.keys.sorted(), id: \.self) { component in
                    if let temperature = snapshot.componentTemperatures[component] {
                        MiniMetric(icon: "thermometer", title: component, value: MetricsFormatter.temperature(temperature))
                    }
                }
            }
        }
    }

    private func batteryDetail(_ snapshot: SystemSnapshot) -> String {
        let status = snapshot.batteryIsCharging == true ? "In carica" : "Non in carica"
        return "\(status) - \(MetricsFormatter.minutes(snapshot.batteryTimeRemainingMinutes))"
    }
}
