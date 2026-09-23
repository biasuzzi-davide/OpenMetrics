import AppKit
import SwiftUI

/// La finestra dello storico e gestita in AppKit invece che come `Scene` SwiftUI:
/// un'app da barra menu non deve aprire finestre all'avvio, ma deve poterle
/// riaprire dal pannello, dal Dock e dal Finder.
@MainActor
final class UsageWindowController: NSObject, NSWindowDelegate {
    static let shared = UsageWindowController()

    let store = UsageHistoryStore()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            DockPolicy.windowDidAppear()
            return
        }

        let controller = NSHostingController(rootView: UsageWindow(store: store))
        if #available(macOS 14.0, *) {
            // Titolo, sottotitolo e toolbar dichiarati in SwiftUI finiscono nella barra della finestra.
            controller.sceneBridgingOptions = [.title, .toolbars]
        }

        let window = NSWindow(contentViewController: controller)
        window.title = "Utilizzo AI"
        window.setContentSize(NSSize(width: 1_120, height: 740))
        window.contentMinSize = NSSize(width: 880, height: 560)
        // Con il contenuto a tutta altezza la sidebar sale fin sotto la toolbar, come in Finder.
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("OpenMetricsUsageWindow")
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
        DockPolicy.windowDidAppear()
    }

    func windowWillClose(_ notification: Notification) {
        DockPolicy.windowDidDisappear()
    }
}

/// Riapre lo storico quando si clicca l'icona nel Dock o si rilancia l'app dal Finder.
final class OpenMetricsAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows else { return true }
        MainActor.assumeIsolated { UsageWindowController.shared.show() }
        return true
    }
}
