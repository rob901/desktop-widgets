import AppKit

/// Magnetic alignment for moving and resizing widgets, similar to the guides in
/// Keynote/Freeform: edges and sizes pull toward other widgets, the screen edges,
/// and preferred sizes when they come within a few points. Hold ⌘ to bypass.
public enum Snapper {
    public static let threshold: CGFloat = 8

    public struct Context {
        public var frames: [NSRect]    // other widgets as they currently appear
        public var sizes: [NSSize]     // other widgets' expanded sizes, plus any preferred sizes
        public var screens: [NSRect]   // visible frames of the screens
        public var minSize: NSSize     // sizes below this are never snapped to

        public init(frames: [NSRect], sizes: [NSSize], screens: [NSRect], minSize: NSSize) {
            self.frames = frames
            self.sizes = sizes
            self.screens = screens
            self.minSize = minSize
        }
    }

    /// Snapping is off in settings, or ⌘ is held.
    public static var bypassed: Bool { !DesktopSettings.snapping || NSEvent.modifierFlags.contains(.command) }

    /// The candidate closest to `value`, if one is within the threshold.
    private static func nearest(_ value: CGFloat, _ candidates: [CGFloat]) -> CGFloat? {
        var best: CGFloat?
        var bestDistance = threshold
        for c in candidates where abs(c - value) <= bestDistance {
            bestDistance = abs(c - value)
            best = c
        }
        return best
    }

    /// True if the ranges overlap or nearly touch.
    private static func near(_ a0: CGFloat, _ a1: CGFloat, _ b0: CGFloat, _ b1: CGFloat) -> Bool {
        a0 <= b1 + threshold && b0 <= a1 + threshold
    }

    /// Snaps a proposed frame for a move. Returns the adjusted origin and which axes snapped.
    public static func move(_ f: NSRect, in c: Context) -> (origin: NSPoint, snappedX: CGFloat?, snappedY: CGFloat?) {
        var xs: [CGFloat] = [], ys: [CGFloat] = []
        for o in c.frames {
            xs += [o.minX, o.maxX - f.width]                       // align left / right edges
            ys += [o.maxY - f.height, o.minY]                      // align top / bottom edges
            if near(f.minY, f.maxY, o.minY, o.maxY) {
                xs += [o.maxX, o.minX - f.width]                   // sit beside it
            }
            if near(f.minX, f.maxX, o.minX, o.maxX) {
                ys += [o.minY - f.height, o.maxY]                  // stack below / above it
            }
        }
        for s in c.screens {
            xs += [s.minX, s.maxX - f.width]
            ys += [s.minY, s.maxY - f.height]
        }
        let x = nearest(f.minX, xs), y = nearest(f.minY, ys)
        return (NSPoint(x: x ?? f.minX, y: y ?? f.minY), x, y)
    }

    /// Snaps a proposed size for a resize from the bottom-right corner (top-left stays fixed).
    public static func resize(_ f: NSRect, in c: Context) -> (size: NSSize, snappedW: CGFloat?, snappedH: CGFloat?) {
        var ws = c.sizes.map(\.width), hs = c.sizes.map(\.height)
        for o in c.frames {
            ws.append(o.maxX - f.minX)                             // right edges line up
            hs.append(f.maxY - o.minY)                             // bottom edges line up
            if near(f.minY, f.maxY, o.minY, o.maxY) { ws.append(o.minX - f.minX) }   // touch its left edge
            if near(f.minX, f.maxX, o.minX, o.maxX) { hs.append(f.maxY - o.maxY) }   // touch its top edge
        }
        for s in c.screens {
            ws.append(s.maxX - f.minX)
            hs.append(f.maxY - s.minY)
        }
        ws = ws.filter { $0 >= c.minSize.width }
        hs = hs.filter { $0 >= c.minSize.height }
        let w = nearest(f.width, ws), h = nearest(f.height, hs)
        return (NSSize(width: w ?? f.width, height: h ?? f.height), w, h)
    }
}

/// Plays the trackpad's "alignment" tick each time a snap engages, like the system does.
public struct SnapFeedback {
    private var last: (CGFloat?, CGFloat?) = (nil, nil)

    public init() {}

    public mutating func update(_ a: CGFloat?, _ b: CGFloat?) {
        let engagedNew = (a != nil && a != last.0) || (b != nil && b != last.1)
        if engagedNew {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        last = (a, b)
    }
}
