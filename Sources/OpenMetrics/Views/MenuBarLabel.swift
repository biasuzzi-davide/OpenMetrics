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
        HStack(spacing: 9) {
            ForEach(aiItems) { item in
                AIMenuBarProvider(item: item)
            }

            ForEach(systemItems, id: \.symbol) { item in
                HStack(spacing: 3) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 11, weight: .semibold))
                    StableWidthText(item.text, template: item.template)
                        .font(.system(size: 12, weight: .medium))
                }
            }

            if aiItems.isEmpty && systemItems.isEmpty {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .frame(height: 22)
        .fixedSize(horizontal: true, vertical: true)
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
    }

    private var systemItems: [MenuBarItem] {
        MetricsFormatter.menuBarItems(
            snapshot: snapshot,
            showCPU: settings.showCPUInMenuBar,
            showRAM: settings.showRAMInMenuBar,
            showDisk: settings.showDiskInMenuBar,
            showBattery: settings.showBatteryInMenuBar,
            showNetwork: settings.showNetworkInMenuBar
        )
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

            // Entrambi i layout (una riga grande, due righe piccole) stanno nascosti sotto
            // il valore visibile: la larghezza non cambia quando arrivano i dati.
            ZStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(MenuBarLabelSizing.percentTemplate)
                    Text(MenuBarLabelSizing.percentTemplate)
                }
                .font(.system(size: 9, weight: .medium))
                .hidden()

                Text(MenuBarLabelSizing.percentTemplate)
                    .font(.system(size: 12, weight: .medium))
                    .hidden()

                if let weekly = item.weekly {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.session)
                        Text(weekly)
                    }
                    .font(.system(size: 9, weight: .medium))
                } else {
                    Text(item.session)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .monospacedDigit()
            .lineLimit(1)
        }
        .fixedSize()
    }
}

/// Testo a cifre tabulari che occupa sempre la larghezza del suo segnaposto.
///
/// Lo status item viene ridisegnato a ogni campione: se la larghezza cambia ("9%" contro
/// "12%", o "--" contro "100%"), macOS chiude il pannello aperto. Un segnaposto invisibile
/// con le cifre a tutta larghezza tiene la misura ferma.
struct StableWidthText: View {
    var text: String
    var template: String

    init(_ text: String, template: String? = nil) {
        self.text = text
        self.template = template ?? MenuBarLabelSizing.template(for: text)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Text(template)
                .hidden()
            Text(text)
        }
        .monospacedDigit()
    }
}

enum MenuBarLabelSizing {
    /// Larghezza di una percentuale a tre cifre: copre anche il 100%.
    static let percentTemplate = "888%"
    /// Larghezza di un tasso compatto ("12K", "1,1M"): la M e la lettera piu larga.
    static let bytesTemplate = "888M"

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
