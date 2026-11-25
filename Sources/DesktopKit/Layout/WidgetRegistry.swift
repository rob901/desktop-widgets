import AppKit

/// Every widget window currently on screen in this app. Snapping uses it to find
/// the other windows; apps can use it for things like "Collapse All".
public final class WidgetRegistry {
    public static let shared = WidgetRegistry()

    public private(set) var windows: [WidgetWindow] = []

    func add(_ window: WidgetWindow) {
        if !windows.contains(where: { $0 === window }) { windows.append(window) }
    }

    func remove(_ window: WidgetWindow) {
        windows.removeAll { $0 === window }
    }
}
