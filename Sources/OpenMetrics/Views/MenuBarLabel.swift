import SwiftUI

struct MenuBarLabel: View {
    var snapshot: SystemSnapshot
    var aiSnapshot: AIUsageSnapshot
    @ObservedObject var settings: AppSettings

    private var usageMode: AIUsageDisplayMode {
        AIUsageDisplayMode(rawValue: settings.aiUsageDisplayMode) ?? .used
    }

    var body: some View {
        Image(nsImage: renderedImage)
    }

    // MenuBarExtra non ridimensiona lo status item quando la label cambia larghezza:
    // renderizzare tutto in un'unica immagine template evita il contenuto tagliato.
    private var renderedImage: NSImage {
        let renderer = ImageRenderer(content: labelContent)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else {
            return NSImage(size: NSSize(width: 1, height: 20))
        }

        image.isTemplate = true
        return image
    }

    private var labelContent: some View {
        HStack(spacing: 8) {
            ForEach(aiItems) { item in
                AIMenuBarProvider(item: item)
            }

            if showsSystemText {
                Text(aiItems.isEmpty ? systemText : compactSystemText)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(height: 22)
        .fixedSize(horizontal: true, vertical: true)
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
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

            guard case .available = provider.status else {
                return AIMenuBarItem(provider: provider.id, session: "--", weekly: nil)
            }

            let usable = provider.metrics.filter { $0.usedFraction != nil }
            let session = usable.first { $0.title == "Sessione" } ?? usable.first
            let weekly = usable.first { $0.title == "Settimanale" }

            return AIMenuBarItem(
                provider: provider.id,
                session: session?.displayValue(usageMode: usageMode) ?? "--",
                weekly: weekly?.displayValue(usageMode: usageMode)
            )
        }
    }
}

private struct AIMenuBarItem: Identifiable {
    var provider: AIProviderID
    var session: String
    var weekly: String?

    var id: AIProviderID { provider }
}

private struct AIMenuBarProvider: View {
    var item: AIMenuBarItem

    var body: some View {
        HStack(spacing: 4) {
            AIProviderIcon(provider: item.provider, size: 16)

            if let weekly = item.weekly {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.session)
                    Text(weekly)
                }
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
            } else {
                Text(item.session)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .fixedSize()
    }
}
