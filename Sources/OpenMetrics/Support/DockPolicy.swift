import AppKit

/// L'app nasce come accessorio della barra menu (`LSUIElement`). Quando si apre una
/// finestra vera serve anche l'icona nel Dock e la barra dei menu, che tornano a
/// sparire quando l'ultima finestra viene chiusa.
@MainActor
enum DockPolicy {
    private static var openWindows = 0
    private static var pinned = false

    /// Preferenza utente: tieni l'icona nel Dock anche senza finestre aperte.
    static func setPinned(_ value: Bool) {
        pinned = value
        apply()
    }

    static func windowDidAppear() {
        openWindows += 1
        apply()
        NSApp.activate(ignoringOtherApps: true)
    }

    static func windowDidDisappear() {
        openWindows = max(0, openWindows - 1)
        apply()
    }

    private static func apply() {
        let wantsDock = pinned || openWindows > 0
        let target: NSApplication.ActivationPolicy = wantsDock ? .regular : .accessory
        guard NSApp.activationPolicy() != target else { return }
        NSApp.setActivationPolicy(target)
    }
}
