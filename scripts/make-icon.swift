import AppKit
import SwiftUI

// Genera l'iconset dell'app: squircle con gradiente e il simbolo del gauge.
// Uso: swift scripts/make-icon.swift Resources/AppIcon.iconset

struct IconView: View {
    var canvas: CGFloat

    var body: some View {
        // Griglia icone macOS: la forma occupa 824/1024 del canvas, il resto e trasparente.
        let side = canvas * 824 / 1024
        let shape = RoundedRectangle(cornerRadius: side * 0.2237, style: .continuous)

        ZStack {
            shape.fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.78, blue: 0.84),
                        Color(red: 0.11, green: 0.42, blue: 0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.32), Color.white.opacity(0)],
                    center: UnitPoint(x: 0.3, y: 0.12),
                    startRadius: 0,
                    endRadius: side * 0.85
                )
            )

            shape.strokeBorder(Color.white.opacity(0.18), lineWidth: max(1, side * 0.006))

            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: side * 0.56, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.28), radius: side * 0.03, y: side * 0.018)
        }
        .frame(width: side, height: side)
        .frame(width: canvas, height: canvas)
    }
}

@MainActor
func render(pixels: Int, to url: URL) throws {
    let renderer = ImageRenderer(content: IconView(canvas: CGFloat(pixels)))
    renderer.scale = 1
    guard let cgImage = renderer.cgImage else {
        throw NSError(domain: "make-icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "render fallito per \(pixels)px"])
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "make-icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "PNG fallito per \(pixels)px"])
    }
    try data.write(to: url)
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write("uso: swift scripts/make-icon.swift <cartella.iconset>\n".data(using: .utf8)!)
    exit(1)
}

let output = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

try MainActor.assumeIsolated {
    for size in sizes {
        try render(pixels: size.pixels, to: output.appendingPathComponent("\(size.name).png"))
    }
}
print("iconset scritto in \(output.path)")
