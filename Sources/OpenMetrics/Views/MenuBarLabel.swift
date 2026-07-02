import SwiftUI

struct MenuBarLabel: View {
    var snapshot: SystemSnapshot
    var aiSnapshot: AIUsageSnapshot
    @ObservedObject var settings: AppSettings

    private var usageMode: AIUsageDisplayMode {
        AIUsageDisplayMode(rawValue: settings.aiUsageDisplayMode) ?? .used
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(aiItems) { item in
                AIMenuBarProvider(item: item)
            }

            if showsSystemText {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    Text(aiItems.isEmpty ? systemText : compactSystemText)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
        .frame(height: 20)
        .fixedSize(horizontal: true, vertical: true)
    }

    private var systemText: String {
        MetricsFormatter.menuBarText(
            snapshot: snapshot,
            showCPU: settings.showCPUInMenuBar,
            showRAM: settings.showRAMInMenuBar,
            showDisk: settings.showDiskInMenuBar,
            showBattery: settings.showBatteryInMenuBar,
            showNetwork: settings.showNetworkInMenuBar
        )
    }

    private var compactSystemText: String {
        MetricsFormatter.compactMenuBarText(
            snapshot: snapshot,
            showCPU: settings.showCPUInMenuBar,
            showRAM: settings.showRAMInMenuBar,
            showDisk: settings.showDiskInMenuBar,
            showBattery: settings.showBatteryInMenuBar,
            showNetwork: settings.showNetworkInMenuBar
        )
    }

    private var showsSystemText: Bool {
        systemText != "OpenMetrics" || aiItems.isEmpty
    }

    private var aiItems: [AIMenuBarItem] {
        aiSnapshot.providers.compactMap { provider in
            guard (provider.id == .claude && settings.showClaudeInMenuBar) || (provider.id == .codex && settings.showCodexInMenuBar) else {
                return nil
            }

            let value: String
            if case .available = provider.status {
                value = provider.metrics
                    .first { $0.usedFraction != nil }?
                    .displayValue(usageMode: usageMode) ?? "--"
            } else {
                value = "--"
            }

            return AIMenuBarItem(provider: provider.id, value: value)
        }
    }
}

private struct AIMenuBarItem: Identifiable {
    var provider: AIProviderID
    var value: String

    var id: AIProviderID { provider }
}

private struct AIMenuBarProvider: View {
    var item: AIMenuBarItem

    var body: some View {
        HStack(spacing: 4) {
            AIProviderIcon(provider: item.provider, size: 14)

            Text(item.value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(width: 46, height: 20, alignment: .leading)
        .fixedSize()
    }
}
