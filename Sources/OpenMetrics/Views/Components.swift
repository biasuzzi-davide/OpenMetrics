import AppKit
import SwiftUI

/// Riga di metrica: badge colorato, titolo, valore e barra di capacita nella stessa tinta.
struct MetricRow: View {
    var icon: String
    var title: String
    var value: String
    var detail: String
    var progress: Double?
    var tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconBadge(systemName: icon, tint: tint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Spacer(minLength: 8)
                    Text(value)
                        .font(.body.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText())
                        .lineLimit(1)
                }

                if let progress {
                    CapacityBar(fraction: progress, tint: tint)
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .animation(.easeOut(duration: 0.3), value: value)
    }
}

struct MiniMetric: View {
    var icon: String
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            IconBadge(systemName: icon, tint: tint, size: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .card(.panel, cornerRadius: 10)
        .animation(.easeOut(duration: 0.3), value: value)
    }
}

struct AIProviderIcon: View {
    var provider: AIProviderID
    var size: CGFloat

    var body: some View {
        Group {
            if let image = AIProviderAppIcons.icon(for: provider) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(.primary)
            } else {
                Image(systemName: provider.icon)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(provider.rawValue)
    }
}

/// Marchio del provider: icona dell'app (o simbolo di sistema) nella sua tinta, su un disco leggero.
struct AIProviderBadge: View {
    var provider: AIProviderID
    var size: CGFloat = 26

    var body: some View {
        let tint = MetricTint.provider(provider)

        ZStack {
            Circle()
                .fill(tint.opacity(0.16))

            if let image = AIProviderAppIcons.icon(for: provider) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(tint)
                    .padding(size * 0.24)
            } else {
                Image(systemName: provider.icon)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(provider.rawValue)
    }
}

enum AIProviderAppIcons {
    static let claude = load(bundleID: "com.anthropic.claudefordesktop", fallback: "/Applications/Claude.app")
    static let codex = load(bundleID: "com.openai.codex", fallback: "/Applications/Codex.app")

    static func icon(for provider: AIProviderID) -> NSImage? {
        switch provider {
        case .claude:
            return claude
        case .codex:
            return codex
        }
    }

    private static func load(bundleID: String, fallback: String) -> NSImage? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            if let image = resourceNames(for: bundleID).compactMap({ loadResource($0, in: url) }).first {
                return image
            }
        }

        let url = URL(fileURLWithPath: fallback)
        return resourceNames(for: bundleID).compactMap { loadResource($0, in: url) }.first
    }

    private static func resourceNames(for bundleID: String) -> [String] {
        bundleID == "com.openai.codex" ? ["codexTemplate@2x", "codexTemplate"] : ["TrayIconTemplate@2x", "TrayIconTemplate"]
    }

    private static func loadResource(_ name: String, in appURL: URL) -> NSImage? {
        let url = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(name).png")
        guard let image = NSImage(contentsOf: url) else { return nil }
        let trimmed = trimmingTransparentBorder(image)
        trimmed.isTemplate = true
        return trimmed
    }

    // Le icone tray hanno margini trasparenti diversi tra loro: senza crop
    // la stessa cornice le mostra a grandezze percepite diverse.
    private static func trimmingTransparentBorder(_ image: NSImage) -> NSImage {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                  data: nil,
                  width: cg.width,
                  height: cg.height,
                  bitsPerComponent: 8,
                  bytesPerRow: cg.width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return image
        }

        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard let data = context.data else { return image }
        let pixels = data.bindMemory(to: UInt8.self, capacity: cg.width * cg.height * 4)

        var minX = cg.width, minY = cg.height, maxX = -1, maxY = -1
        for y in 0..<cg.height {
            for x in 0..<cg.width where pixels[(y * cg.width + x) * 4 + 3] > 8 {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY,
              let cropped = cg.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
        else {
            return image
        }

        return NSImage(cgImage: cropped, size: .zero)
    }
}
