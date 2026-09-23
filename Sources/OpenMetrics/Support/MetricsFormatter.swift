import Foundation

struct MetricsFormatter {
    static func percent(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    static func bytes(_ value: UInt64) -> String {
        // "0 KB" invece di "Zero KB": in una riga di numeri la parola stona.
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(min(value, UInt64(Int64.max))))
    }

    /// "942 B/s", "12 KB/s", "1,1 MB/s": corto e a cifre stabili, pensato per i moduli.
    static func rate(_ value: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var scaled = Double(value)
        var unit = 0
        while scaled >= 1_000, unit < units.count - 1 {
            scaled /= 1_000
            unit += 1
        }
        let digits = unit > 0 && scaled < 10 ? 1 : 0
        let number = scaled.formatted(.number.precision(.fractionLength(digits)))
        return "\(number) \(units[unit])/s"
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

    static func temperature(_ celsius: Double) -> String {
        String(format: "%.1f°C", celsius)
    }

    /// Voci della barra menu: un simbolo e un valore corto, niente sigle da decifrare.
    static func menuBarItems(
        snapshot: SystemSnapshot,
        showCPU: Bool,
        showRAM: Bool,
        showDisk: Bool,
        showBattery: Bool,
        showNetwork: Bool
    ) -> [MenuBarItem] {
        var items: [MenuBarItem] = []

        if showCPU {
            items.append(MenuBarItem(symbol: "cpu", text: percent(snapshot.cpuUsage), template: MenuBarLabelSizing.percentTemplate))
        }
        if showRAM {
            items.append(MenuBarItem(symbol: "memorychip", text: percent(snapshot.memoryUsage), template: MenuBarLabelSizing.percentTemplate))
        }
        if showDisk {
            items.append(MenuBarItem(symbol: "internaldrive", text: percent(snapshot.diskUsage), template: MenuBarLabelSizing.percentTemplate))
        }
        if showBattery, let batteryPercent = snapshot.batteryPercent {
            let symbol = snapshot.batteryIsCharging == true ? "battery.100.bolt" : "battery.100"
            items.append(MenuBarItem(symbol: symbol, text: percent(batteryPercent), template: MenuBarLabelSizing.percentTemplate))
        }
        if showNetwork {
            items.append(MenuBarItem(symbol: "arrow.down", text: compactBytes(snapshot.networkInPerSecond), template: MenuBarLabelSizing.bytesTemplate))
            items.append(MenuBarItem(symbol: "arrow.up", text: compactBytes(snapshot.networkOutPerSecond), template: MenuBarLabelSizing.bytesTemplate))
        }

        return items
    }

    static func aiMenuBarText(
        snapshot: AIUsageSnapshot,
        showClaude: Bool,
        showCodex: Bool,
        usageMode: AIUsageDisplayMode,
        resetMode: AIResetDisplayMode
    ) -> String {
        let parts = snapshot.providers.compactMap { provider -> String? in
            let isEnabled = (provider.id == .claude && showClaude) || (provider.id == .codex && showCodex)
            guard isEnabled,
                  case .available = provider.status,
                  let metric = provider.metrics.first(where: { $0.usedFraction != nil })
            else {
                return nil
            }

            let prefix = provider.id == .claude ? "CLA" : "COD"
            let reset = metric.menuBarReset(resetMode: resetMode).map { " \($0)" } ?? ""
            return "\(prefix) \(metric.displayValue(usageMode: usageMode))\(reset)"
        }

        return parts.joined(separator: "  ")
    }

    /// Solo le cifre della percentuale, per i numeri grandi con l'unita separata.
    static func percentDigits(_ value: Double) -> String {
        String(Int((min(max(value, 0), 1) * 100).rounded()))
    }

    private static func compactBytes(_ value: UInt64) -> String {
        if value >= 1_000_000_000 { return "\(value / 1_000_000_000)G" }
        if value >= 1_000_000 { return "\(value / 1_000_000)M" }
        if value >= 1_000 { return "\(value / 1_000)K" }
        return "\(value)B"
    }
}

struct MenuBarItem: Equatable, Sendable {
    var symbol: String
    var text: String
    /// Testo invisibile che fissa la larghezza della voce.
    var template: String
}
