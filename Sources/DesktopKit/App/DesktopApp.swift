import AppKit

/// Standard items the framework can add to a widget app's menu-bar menu.
public struct StandardMenuItems: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let preferences = StandardMenuItems(rawValue: 1 << 0)   // only if the app has a preferences pane
    public static let openAtLogin = StandardMenuItems(rawValue: 1 << 1)
    public static let revealData  = StandardMenuItems(rawValue: 1 << 2)   // only if the app has a data file
    public static let quit        = StandardMenuItems(rawValue: 1 << 3)
    public static let all: StandardMenuItems = [.preferences, .openAtLogin, .revealData, .quit]
}

/// A menu-bar icon for a widget app.
public struct StatusItemConfig {
    public var symbolName: String
    public var standardItems: StandardMenuItems
    public var revealDataTitle: String

    public init(symbolName: String, standardItems: StandardMenuItems = .all,
                revealDataTitle: String = "Show Data in Finder") {
        self.symbolName = symbolName
        self.standardItems = standardItems
        self.revealDataTitle = revealDataTitle
    }
}

public struct DesktopAppInfo {
    /// Display name, e.g. "Desktop Notes". Used in "Quit <name>" and "<name> Preferences".
    public var name: String
    /// nil: the app has no menu-bar icon.
    public var statusItem: StatusItemConfig?

    public init(name: String, statusItem: StatusItemConfig?) {
        self.name = name
        self.statusItem = statusItem
    }
}

/// A widget app. Pass one to `DesktopApp.run`.
public protocol DesktopWidgetApp: AnyObject {
    var info: DesktopAppInfo { get }
    /// Create or restore windows.
    func didLaunch()
    /// Flush anything unsaved.
    func willTerminate()
    /// The app's own menu-bar items, shown above the standard ones.
    func statusMenuItems() -> [NSMenuItem]
    /// nil: no Preferences window.
    var preferencesPane: PreferencesPane? { get }
    /// For the "Show … in Finder" menu item; nil hides it.
    var dataFileURL: URL? { get }
}

public extension DesktopWidgetApp {
    func willTerminate() {}
    func statusMenuItems() -> [NSMenuItem] { [] }
    var preferencesPane: PreferencesPane? { nil }
    var dataFileURL: URL? { nil }
}

public enum DesktopApp {
    /// The running app's host, available once `run` is called.
    public private(set) static var host: DesktopHost!

    /// Starts the app as a background (accessory) app with no Dock icon. Never returns.
    public static func run(_ app: DesktopWidgetApp) -> Never {
        let nsApp = NSApplication.shared
        let host = DesktopHost(app: app)
        self.host = host
        nsApp.delegate = host
        nsApp.setActivationPolicy(.accessory)
        nsApp.run()
        exit(0)
    }
}

/// Runs a widget app: lifecycle, the optional menu-bar icon, and the preferences window.
public final class DesktopHost: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public let app: DesktopWidgetApp
    private var statusItem: NSStatusItem?
    private var launchAtLoginItem: NSMenuItem?
    private var preferences: PreferencesController?

    init(app: DesktopWidgetApp) {
        self.app = app
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        if let pane = app.preferencesPane {
            preferences = PreferencesController(title: "\(app.info.name) Preferences", pane: pane)
        }
        if let config = app.info.statusItem { setUpStatusItem(config) }
        app.didLaunch()
    }

    public func applicationWillTerminate(_ notification: Notification) { app.willTerminate() }

    // MARK: Preferences

    /// Shows the preferences window. This activates the app (ending Show Desktop, as any app would).
    @objc public func openPreferences() { preferences?.show() }

    /// Asks the preferences pane to refresh, if the window is open.
    public func refreshPreferences() { preferences?.refreshIfVisible() }

    @objc public func quit() { NSApp.terminate(nil) }

    // MARK: Menu bar

    private func setUpStatusItem(_ config: StatusItemConfig) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: config.symbolName, accessibilityDescription: app.info.name)

        let menu = NSMenu()
        menu.delegate = self
        let appItems = app.statusMenuItems()
        appItems.forEach(menu.addItem)

        var standard: [NSMenuItem] = []
        let s = config.standardItems
        if s.contains(.preferences), preferences != nil {
            standard.append(menuItem("Preferences…", #selector(openPreferences)))
        }
        if s.contains(.openAtLogin) {
            let i = menuItem("Open at Login", #selector(toggleLaunchAtLogin))
            launchAtLoginItem = i
            standard.append(i)
        }
        if s.contains(.revealData), app.dataFileURL != nil {
            standard.append(menuItem(config.revealDataTitle, #selector(revealData)))
        }
        if !standard.isEmpty {
            if !appItems.isEmpty { menu.addItem(.separator()) }
            standard.forEach(menu.addItem)
        }
        if s.contains(.quit) {
            if menu.numberOfItems > 0 { menu.addItem(.separator()) }
            menu.addItem(menuItem("Quit \(app.info.name)", #selector(quit)))
        }
        item.menu = menu
        statusItem = item
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    public func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() { LaunchAtLogin.toggle() }

    @objc private func revealData() {
        if let url = app.dataFileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
}
