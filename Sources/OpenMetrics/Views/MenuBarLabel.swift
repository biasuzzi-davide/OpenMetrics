import SwiftUI

struct MenuBarLabel: View {
    var snapshot: SystemSnapshot
    var aiSnapshot: AIUsageSnapshot

    @AppStorage(SettingsKey.showCPUInMenuBar) private var showCPU = true
    @AppStorage(SettingsKey.showRAMInMenuBar) private var showRAM = true
    @AppStorage(SettingsKey.showDiskInMenuBar) private var showDisk = false
    @AppStorage(SettingsKey.showBatteryInMenuBar) private var showBattery = true
    @AppStorage(SettingsKey.showNetworkInMenuBar) private var showNetwork = false
    @AppStorage(SettingsKey.showClaudeInMenuBar) private var showClaude = false
    @AppStorage(SettingsKey.showCodexInMenuBar) private var showCodex = false
    @AppStorage(SettingsKey.aiUsageDisplayMode) private var usageModeRaw = AIUsageDisplayMode.used.rawValue

    private var usageMode: AIUsageDisplayMode {
        AIUsageDisplayMode(rawValue: usageModeRaw) ?? .used
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(aiItems) { item in
                AIMenuBarProvider(item: item)
            }

            if showsSystemText {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    Text(systemText)
                        .monospacedDigit()
                }
            }
        }
        .frame(height: 20)
    }

    private var systemText: String {
        MetricsFormatter.menuBarText(
            snapshot: snapshot,
            showCPU: showCPU,
            showRAM: showRAM,
            showDisk: showDisk,
            showBattery: showBattery,
            showNetwork: showNetwork
        )
    }

    private var showsSystemText: Bool {
        systemText != "OpenMetrics" || aiItems.isEmpty
    }

    private var aiItems: [AIMenuBarItem] {
        aiSnapshot.providers.compactMap { provider in
            guard (provider.id == .claude && showClaude) || (provider.id == .codex && showCodex) else {
                return nil
            }

            let values: [String]
            if case .available = provider.status {
                values = provider.metrics
                    .filter { $0.usedFraction != nil }
                    .prefix(2)
                    .map { $0.displayValue(usageMode: usageMode) }
            } else {
                values = []
            }

            return AIMenuBarItem(provider: provider.id, values: Array(values))
        }
    }
}

private struct AIMenuBarItem: Identifiable {
    var provider: AIProviderID
    var values: [String]

    var id: AIProviderID { provider }
}

private struct AIMenuBarProvider: View {
    var item: AIMenuBarItem

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: -3) {
                ForEach(Array(displayValues.enumerated()), id: \.offset) { _, value in
                    Text(value)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
        .frame(height: 20)
        .fixedSize()
    }

    private var icon: String {
        switch item.provider {
        case .claude:
            return "asterisk"
        case .codex:
            return "circle.hexagongrid"
        }
    }

    private var displayValues: [String] {
        if item.values.count > 1 { return item.values }
        if item.values.count == 1 { return [item.values[0], "--"] }
        return ["--", "--"]
    }
}
