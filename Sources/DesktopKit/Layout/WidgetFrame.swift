import AppKit

/// A widget window's saved geometry, in screen coordinates (y up).
public struct WidgetFrame: Codable, Equatable {
    public var x: Double
    public var top: Double       // y of the window's top edge
    public var width: Double
    public var height: Double    // expanded height, kept while collapsed
    public var collapsed: Bool

    public init(x: Double, top: Double, width: Double, height: Double, collapsed: Bool = false) {
        self.x = x
        self.top = top
        self.width = width
        self.height = height
        self.collapsed = collapsed
    }

    /// A frame saved on a display that's no longer attached is moved to the middle of `fallback`
    /// (by default the main screen). A frame counts as on-screen if its header strip is visible.
    public func fittedOnScreen(visibleFrames: [NSRect]? = nil, fallback: NSRect? = nil,
                               probeHeight: Double = 22) -> WidgetFrame {
        let screens = visibleFrames ?? NSScreen.screens.map(\.visibleFrame)
        let probe = NSRect(x: x, y: top - probeHeight, width: width, height: probeHeight)
        if screens.contains(where: { $0.intersects(probe) }) { return self }
        let vf = fallback ?? (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        var f = self
        f.x = vf.midX - width / 2
        f.top = vf.midY + height / 2
        return f
    }
}
