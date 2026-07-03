import AppKit
import SwiftUI

struct Footer: View {
    var store: MetricsStore
    var snapshot: SystemSnapshot

    var body: some View {
        HStack(spacing: 10) {
            Text("Uptime \(MetricsFormatter.duration(snapshot.uptime))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.refresh()
            } label: {
                Label("Aggiorna", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Esci", systemImage: "power")
            }
            .buttonStyle(.bordered)
        }
    }
}

struct MetricRow: View {
    var icon: String
    var title: String
    var value: String
    var detail: String
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text(title)
                Spacer()
                Text(value)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct MiniMetric: View {
    var icon: String
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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

private enum AIProviderAppIcons {
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

struct DetailSection<Content: View>: View {
    var title: String
    var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct InfoRow: View {
    var title: String
    var value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption)
    }
}
