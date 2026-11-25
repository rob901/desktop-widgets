import AppKit

/// Runs a mouse-drag loop until the button is released, reporting the distance
/// moved since `mouseDown` (in screen points, y up).
public func trackDrag(from mouseDown: NSEvent, in window: NSWindow, _ step: (_ delta: NSPoint) -> Void) {
    // Use each event's own global position (not the live cursor), so the deltas
    // are exact even if events queue up.
    func location(_ e: NSEvent) -> CGPoint { e.cgEvent?.location ?? .zero }   // top-left origin
    let start = location(mouseDown)
    var moved = false
    while let e = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
        let p = location(e)
        if e.type == .leftMouseDragged { moved = true }
        // Apply the release position too: the last drag event can be coalesced into the mouse-up.
        if moved { step(NSPoint(x: p.x - start.x, y: start.y - p.y)) }
        if e.type == .leftMouseUp { break }
    }
}

/// Top strip: drag to move, double-click to collapse/expand, right-click for a menu.
final class HeaderBarView: NSView {
    var fill: NSColor = .clear { didSet { needsDisplay = true } }
    var onDoubleClick: (() -> Void)?
    var onDrag: ((_ delta: NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    var menuProvider: (() -> NSMenu?)?

    override func draw(_ dirtyRect: NSRect) {
        fill.setFill()
        bounds.fill()
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        guard let window else { return }
        window.makeKey()
        trackDrag(from: event, in: window) { onDrag?($0) }
        onDragEnded?()
    }

    override func menu(for event: NSEvent) -> NSMenu? { menuProvider?() }
}

/// Bottom-right resize corner (borderless windows have no edges to drag).
final class ResizeGripView: NSView {
    var onDrag: ((_ delta: NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setStroke()
        let path = NSBezierPath()
        for inset in stride(from: CGFloat(3), through: 9, by: 3) {
            path.move(to: NSPoint(x: bounds.maxX - inset - 1, y: 2))
            path.line(to: NSPoint(x: bounds.maxX - 2, y: inset + 1))
        }
        path.lineWidth = 1
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        trackDrag(from: event, in: window) { onDrag?($0) }
        onDragEnded?()
    }
}

/// The panel's content view: lays out the chrome whenever the panel resizes.
final class WidgetContainerView: NSView {
    var onResize: (() -> Void)?
    override func resizeSubviews(withOldSize oldSize: NSSize) { onResize?() }
}
