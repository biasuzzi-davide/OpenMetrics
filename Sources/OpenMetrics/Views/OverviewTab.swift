import SwiftUI

struct OverviewTab: View {
    var snapshot: SystemSnapshot
    var history: MetricHistory

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    HeroTile(
                        title: "CPU",
                        symbol: "cpu",
                        fraction: snapshot.cpuUsage,
                        tint: MetricTint.usage(snapshot.cpuUsage, base: MetricTint.cpu),
                        detail: "load \(MetricsFormatter.loadAverage(snapshot.loadAverage))",
                        history: history.cpu
                    )

                    HeroTile(
                        title: "RAM",
                        symbol: "memorychip",
                        fraction: snapshot.memoryUsage,
                        tint: MetricTint.usage(snapshot.memoryUsage, base: MetricTint.memory),
                        detail: "\(MetricsFormatter.bytes(snapshot.memoryUsed)) su \(MetricsFormatter.bytes(snapshot.memoryTotal))",
                        history: history.memory
                    )
                }

                HStack(spacing: 12) {
                    CompactTile(
                        title: "Disco",
                        symbol: "internaldrive",
                        fraction: snapshot.diskUsage,
                        tint: MetricTint.usage(snapshot.diskUsage, base: MetricTint.disk, warning: 0.9, critical: 0.97),
                        detail: "\(MetricsFormatter.bytes(snapshot.diskAvailable)) liberi"
                    )

                    if let batteryPercent = snapshot.batteryPercent {
                        let charging = snapshot.batteryIsCharging == true

                        CompactTile(
                            title: "Batteria",
                            symbol: charging ? "battery.100.bolt" : "battery.100",
                            fraction: batteryPercent,
                            tint: MetricTint.battery(batteryPercent, charging: charging),
                            detail: batteryDetail(snapshot, charging: charging)
                        )
                    } else {
                        CompactTile(
                            title: "Swap",
                            symbol: "arrow.left.arrow.right",
                            fraction: snapshot.swapUsage,
                            tint: MetricTint.usage(snapshot.swapUsage, base: MetricTint.memory),
                            detail: "\(MetricsFormatter.bytes(snapshot.swapUsed)) su \(MetricsFormatter.bytes(snapshot.swapTotal))"
                        )
                    }
                }

                NetworkTile(snapshot: snapshot, history: history)

                if !snapshot.componentTemperatures.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(snapshot.componentTemperatures.keys.sorted(), id: \.self) { component in
                            if let temperature = snapshot.componentTemperatures[component] {
                                TemperatureTile(name: component, celsius: temperature)
                            }
                        }
                    }
                }

                OverviewFooter(snapshot: snapshot)
            }
            .padding(.bottom, 2)
        }
    }

    private func batteryDetail(_ snapshot: SystemSnapshot, charging: Bool) -> String {
        let status = charging ? "In carica" : "Non in carica"
        return "\(status) · \(MetricsFormatter.minutes(snapshot.batteryTimeRemainingMinutes))"
    }
}

/// Modulo principale: anello, numero grande e andamento degli ultimi campioni.
private struct HeroTile: View {
    var title: String
    var symbol: String
    var fraction: Double
    var tint: Color
    var detail: String
    var history: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TileLabel(title: title, symbol: symbol)

            HStack(spacing: 10) {
                RingGauge(value: fraction, tint: tint)
                    .frame(width: 38, height: 38)
                BigValue(number: MetricsFormatter.percentDigits(fraction), unit: "%")
                Spacer(minLength: 0)
            }

            Sparkline(series: [SparklineSeries(id: title, values: history, tint: tint)])
                .frame(height: 34)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tile()
    }
}

private struct CompactTile: View {
    var title: String
    var symbol: String
    var fraction: Double
    var tint: Color
    var detail: String

    var body: some View {
        HStack(spacing: 10) {
            RingGauge(value: fraction, tint: tint)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                TileLabel(title: title, symbol: symbol)
                BigValue(number: MetricsFormatter.percentDigits(fraction), unit: "%", size: 22)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tile()
    }
}

private struct NetworkTile: View {
    var snapshot: SystemSnapshot
    var history: MetricHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TileLabel(title: "Rete", symbol: "network")
                Spacer()
                if let interface = snapshot.networkInterface {
                    Text([interface, snapshot.ipAddress].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                RateValue(symbol: "arrow.down", value: MetricsFormatter.rate(snapshot.networkInPerSecond), tint: MetricTint.networkIn)
                RateValue(symbol: "arrow.up", value: MetricsFormatter.rate(snapshot.networkOutPerSecond), tint: MetricTint.networkOut)
                Spacer(minLength: 0)
            }

            Sparkline(
                series: [
                    SparklineSeries(id: "in", values: history.networkIn, tint: MetricTint.networkIn),
                    SparklineSeries(id: "out", values: history.networkOut, tint: MetricTint.networkOut)
                ],
                range: .adaptive(floor: 0)
            )
            .frame(height: 32)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tile()
    }
}

private struct RateValue: View {
    var symbol: String
    var value: String
    var tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .animation(.easeOut(duration: 0.3), value: value)
    }
}

private struct TemperatureTile: View {
    var name: String
    var celsius: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            TileLabel(title: name, symbol: "thermometer.medium")
            BigValue(number: String(format: "%.1f", celsius), unit: "°C", size: 20)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tile()
    }
}

/// Riga di chiusura con le voci che non meritano un modulo.
private struct OverviewFooter: View {
    var snapshot: SystemSnapshot

    var body: some View {
        HStack(spacing: 14) {
            Label(MetricsFormatter.thermal(snapshot.thermalState), systemImage: "thermometer.medium")
                .foregroundStyle(snapshot.thermalState == .nominal ? AnyShapeStyle(.secondary) : AnyShapeStyle(MetricTint.thermal(snapshot.thermalState)))
            Label(MetricsFormatter.duration(snapshot.uptime), systemImage: "clock")
            Label("\(snapshot.activeProcessorCount) core", systemImage: "cpu")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}
