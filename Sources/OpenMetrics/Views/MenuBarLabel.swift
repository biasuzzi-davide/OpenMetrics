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
                StableWidthText(aiItems.isEmpty ? systemText : compactSystemText)
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
                    StableWidthText(item.session)
                    StableWidthText(weekly)
                }
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
            } else {
                StableWidthText(item.session)
                    .lineLimit(1)
            }
        }
        .fixedSize()
    }
}

/// Testo a cifre tabulari che occupa sempre la larghezza del suo valore piu largo.
///
/// Lo status item viene ridisegnato a ogni campione: se la larghezza cambia ("C9" contro
/// "C12"), macOS chiude il pannello aperto. Un segnaposto invisibile con le cifre a
/// tutta larghezza tiene la misura ferma finche non cambia il numero di cifre massimo.
struct StableWidthText: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Text(MenuBarLabelSizing.template(for: text))
                .hidden()
            Text(text)
        }
        .monospacedDigit()
    }
}

enum MenuBarLabelSizing {
    /// Sostituisce ogni gruppo di cifre con altrettanti "8" (almeno due), la cifra piu
    /// larga nei font di sistema.
    static func template(for text: String) -> String {
        var result = ""
        var run = 0

        func flush() {
            guard run > 0 else { return }
            result += String(repeating: "8", count: max(run, 2))
            run = 0
        }

        for character in text {
            if character.isNumber {
                run += 1
            } else {
                flush()
                result.append(character)
            }
        }
        flush()
        return result
    }
}
