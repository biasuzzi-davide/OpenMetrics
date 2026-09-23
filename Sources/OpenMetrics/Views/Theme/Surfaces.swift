import AppKit
import SwiftUI

/// Quadratino colorato con simbolo: lo stesso linguaggio delle icone di Impostazioni di Sistema.
struct IconBadge: View {
    var systemName: String? = nil
    var image: NSImage? = nil
    var tint: Color
    var size: CGFloat = 26

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay { glyph }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyph: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(.white)
                .padding(size * 0.22)
        } else if let systemName {
            Image(systemName: systemName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

/// Barra di capacita a capsula, sostituisce `ProgressView` con una tinta propria.
struct CapacityBar: View {
    var fraction: Double
    var tint: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(height, geometry.size.width * clamped))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.35), value: fraction)
    }
}

enum CardVariant {
    /// Dentro il pannello traslucido: riempimento leggero che lascia passare il vetro.
    case panel
    /// Dentro una finestra opaca: gruppo rientrato stile Impostazioni di Sistema.
    case window
}

private struct CardModifier: ViewModifier {
    var variant: CardVariant
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch variant {
        case .panel:
            content.background(.quaternary.opacity(0.55), in: shape)
        case .window:
            content
                .background(.quaternary.opacity(0.45), in: shape)
                .overlay(shape.strokeBorder(.quaternary.opacity(0.7), lineWidth: 1))
        }
    }
}

extension View {
    func card(_ variant: CardVariant = .window, cornerRadius: CGFloat = 12) -> some View {
        modifier(CardModifier(variant: variant, cornerRadius: cornerRadius))
    }

    /// Superficie in Liquid Glass su macOS 26, materiale classico prima.
    @ViewBuilder
    func glassSurface<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
        }
        #else
        background(.regularMaterial, in: shape)
        #endif
    }
}

/// Riga separatrice rientrata quanto il badge, come nelle liste di Impostazioni.
struct InsetDivider: View {
    var leading: CGFloat = 46

    var body: some View {
        Divider().padding(.leading, leading)
    }
}

/// Rende trasparente la finestra del `MenuBarExtra` e la riempie con un vetro dietro-finestra:
/// il pannello diventa un pannello di Centro di Controllo invece di una finestra grigia.
struct PanelBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> BackdropView {
        BackdropView()
    }

    func updateNSView(_ nsView: BackdropView, context: Context) {}

    final class BackdropView: NSView {
        static let cornerRadius: CGFloat = 16

        override init(frame: NSRect) {
            super.init(frame: frame)
            let effect = Self.makeEffectView()
            effect.frame = bounds
            effect.autoresizingMask = [.width, .height]
            addSubview(effect)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) non supportato")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
        }

        private static func makeEffectView() -> NSView {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                let glass = NSGlassEffectView()
                glass.cornerRadius = cornerRadius
                return glass
            }
            #endif
            let view = NSVisualEffectView()
            view.material = .popover
            view.blendingMode = .behindWindow
            view.state = .active
            view.wantsLayer = true
            view.layer?.cornerRadius = cornerRadius
            view.layer?.cornerCurve = .continuous
            view.layer?.masksToBounds = true
            return view
        }
    }
}

/// Segnala apertura e chiusura della finestra che ospita la vista, per sincronizzare il Dock.
struct WindowLifecycle: NSViewRepresentable {
    var onOpen: @MainActor () -> Void
    var onClose: @MainActor () -> Void

    func makeNSView(context: Context) -> LifecycleView {
        let view = LifecycleView()
        view.onOpen = onOpen
        view.onClose = onClose
        return view
    }

    func updateNSView(_ nsView: LifecycleView, context: Context) {
        nsView.onOpen = onOpen
        nsView.onClose = onClose
    }

    final class LifecycleView: NSView {
        var onOpen: (@MainActor () -> Void)?
        var onClose: (@MainActor () -> Void)?
        private weak var observedWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window !== observedWindow else { return }
            observedWindow = window
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowWillClose(_:)),
                name: NSWindow.willCloseNotification,
                object: window
            )
            onOpen?()
        }

        @objc private func windowWillClose(_ notification: Notification) {
            observedWindow = nil
            onClose?()
        }
    }
}
