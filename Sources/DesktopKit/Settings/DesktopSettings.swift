import Foundation

/// Settings shared by every widget window in an app, stored in the app's UserDefaults.
public enum DesktopSettings {
    private static let d = UserDefaults.standard

    /// Whether moving and resizing snap to other widgets and screen edges.
    public static var snapping: Bool {
        get { d.object(forKey: "snapping") as? Bool ?? true }
        set { d.set(newValue, forKey: "snapping") }
    }
}
