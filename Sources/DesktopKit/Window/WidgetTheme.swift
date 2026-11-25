import AppKit

/// Colors for a widget window's chrome.
public struct WidgetTheme {
    public var body: NSColor
    public var header: NSColor
    public var border: NSColor
    public var title: NSColor
    public var buttonTint: NSColor

    /// `header` defaults to `body` darkened slightly.
    public init(body: NSColor,
                header: NSColor? = nil,
                border: NSColor = NSColor.black.withAlphaComponent(0.12),
                title: NSColor = NSColor.black.withAlphaComponent(0.7),
                buttonTint: NSColor = NSColor.black.withAlphaComponent(0.5)) {
        self.body = body
        self.header = header ?? body.blended(withFraction: 0.12, of: .black) ?? body
        self.border = border
        self.title = title
        self.buttonTint = buttonTint
    }

    /// A small rounded square in the header color, for menus and pop-ups.
    public func swatch(size: CGFloat = 12) -> NSImage {
        let fill = header
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { r in
            fill.setFill()
            NSBezierPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2).fill()
            return true
        }
    }
}
