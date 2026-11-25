import AppKit

// A desktop panel is a borderless, non-activating panel placed one level above the
// desktop icons, so it is always behind every normal window. The `.stationary`
// collection behavior keeps it in place during Show Desktop / Mission Control,
// and `.canJoinAllSpaces` puts it on every Space. Because the panel never
// activates the app, clicking it doesn't end Show Desktop.

open class DesktopPanel: NSPanel {
    /// One level above the desktop icons: below every normal window.
    public static var desktopLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }

    /// Gets first look at key equivalents (e.g. ⌘B). Return true if handled.
    /// Unhandled cut/copy/paste/select all/undo/redo are then handled by the panel.
    public var keyEquivalentHandler: ((NSEvent) -> Bool)?

    public convenience init(contentRect: NSRect) {
        self.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
                  backing: .buffered, defer: false)
        isFloatingPanel = false
        level = Self.desktopLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isMovable = true
        isReleasedWhenClosed = false
        hasShadow = true
    }

    override open var canBecomeKey: Bool { true }
    override open var canBecomeMain: Bool { false }

    override open func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown, keyEquivalentHandler?(event) == true { return true }
        if performStandardEditShortcut(event, from: self) { return true }
        return super.performKeyEquivalent(with: event)
    }
}
