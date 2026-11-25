import AppKit

/// A widget app's preferences content.
public protocol PreferencesPane: AnyObject {
    /// Add rows to the form. Called once, when the window is first made.
    func build(_ form: PreferencesForm)
    /// Load current values into the controls. Called on show and on `DesktopHost.refreshPreferences()`.
    func refresh()
    /// The window became key again (e.g. the user switched back to it).
    func preferencesDidBecomeKey()
}

public extension PreferencesPane {
    func preferencesDidBecomeKey() {}
}

/// Unlike widget windows, this is an ordinary window: opening it brings the app forward.
final class PreferencesWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if event.type == .keyDown, flags == .command, event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return performStandardEditShortcut(event, from: self) || super.performKeyEquivalent(with: event)
    }
}

final class PreferencesController: NSObject, NSWindowDelegate {
    private let title: String
    private let pane: PreferencesPane
    private var window: PreferencesWindow?
    private var form: PreferencesForm?   // keeps the form's control targets alive

    init(title: String, pane: PreferencesPane) {
        self.title = title
        self.pane = pane
    }

    func show() {
        if window == nil { build() }
        pane.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func refreshIfVisible() {
        guard let window, window.isVisible else { return }
        pane.refresh()
    }

    func windowDidBecomeKey(_ notification: Notification) { pane.preferencesDidBecomeKey() }

    func windowWillClose(_ notification: Notification) {
        // Commit a number that's still being typed.
        window?.makeFirstResponder(nil)
        if NSColorPanel.sharedColorPanelExists { NSColorPanel.shared.orderOut(nil) }
    }

    private func build() {
        let form = PreferencesForm()
        pane.build(form)
        self.form = form
        let grid = form.makeGrid()

        let container = NSView()
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        ])

        let w = PreferencesWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = title
        w.isReleasedWhenClosed = false
        w.contentView = container
        w.delegate = self
        w.setContentSize(container.fittingSize)
        w.center()
        window = w
    }
}
