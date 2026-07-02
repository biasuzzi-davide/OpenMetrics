import Foundation

struct MetricsFormatter {
    static func percent(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(min(value, UInt64(Int64.max))), countStyle: .memory)
    }

    static func rate(_ value: UInt64) -> String {
        "\(bytes(value))/s"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(Int(seconds / 60), 0)
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60

        if days > 0 { return "\(days)g \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    static func minutes(_ value: Int?) -> String {
        guard let value, value >= 0 else { return "n/d" }
        if value >= 60 {
            return "\(value / 60)h \(value % 60)m"
        }
        return "\(value)m"
    }

    static func loadAverage(_ values: [Double]) -> String {
        values.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: " / ")
    }

    static func thermal(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "Normale"
        case .fair:
            return "Caldo"
        case .serious:
            return "Alto"
        case .critical:
            return "Critico"
        @unknown default:
            return "Sconosciuto"
        }
    }

    static func menuBarText(
        snapshot: SystemSnapshot,
        showCPU: Bool,
        showRAM: Bool,
        showDisk: Bool,
        showBattery: Bool,
        showNetwork: Bool
    ) -> String {
        var parts: [String] = []

        if showCPU {
            parts.append("CPU \(percent(snapshot.cpuUsage))")
        }
        if showRAM {
            parts.append("RAM \(percent(snapshot.memoryUsage))")
        }
        if showDisk {
            parts.append("SSD \(percent(snapshot.diskUsage))")
        }
        if showBattery, let batteryPercent = snapshot.batteryPercent {
            parts.append("BAT \(percent(batteryPercent))")
        }
        if showNetwork {
            parts.append("↓ \(bytes(snapshot.networkInPerSecond)) ↑ \(bytes(snapshot.networkOutPerSecond))")
        }

        return parts.isEmpty ? "OpenMetrics" : parts.joined(separator: "  ")
    }
}
