# DesktopKit — framework plan

A small Swift library for building macOS desktop widgets: windows that live just
above the desktop icons, behind every app, on every Space, and stay usable during
Show Desktop.

The framework is invisible: it has no app, icon, or UI of its own. Each widget is
its own app built on the library. A widget app chooses whether it gets a
menu-bar icon (`statusItem: nil` means none) and which standard menu items it
shows. `dt-stickies` is the first app built on it. The framework will change as
more widgets are built.

**Scope for v1:** only what `dt-stickies` needs. Anything else waits until a
second widget (e.g. `dt-claude`) actually needs it. See "Deferred" at the end.

---

## 1. Where the pieces come from

Everything below is already in `desktop-stickies`; the work is mostly moving it
and cutting the ties to `NoteController` / `AppDelegate.shared` / `Prefs`.

| Framework piece | Comes from (desktop-stickies) | What changes |
|---|---|---|
| `DesktopPanel` | `NotePanel` + `configurePanel()` in `Note.swift` | Level, collection behavior, non-activating setup move here. Key equivalents route to a widget-supplied handler before the standard edit shortcuts. |
| `performStandardEditShortcut` | `Model.swift` | Moved as-is (public). |
| `trackDrag` | `Note.swift` | Moved as-is (public). |
| `HeaderBarView`, `ResizeGripView` | `HeaderView`, `GripView` | Moved as-is. |
| `WidgetWindow` (chrome + frame behavior) | Most of `NoteController` *except* the text view | Owns panel, header, grip, title label, collapse button, move/resize with snapping, collapse/expand with top pinned, theme colors. Widget supplies a content view. |
| `Snapper`, `SnapFeedback` | `Snapping.swift` | Context comes from `WidgetRegistry` instead of `AppDelegate.shared.notes`; min size and "preferred sizes" are parameters, not globals. |
| `WidgetFrame` + `fitOnScreen` | `NoteData` geometry fields, `AppDelegate.fitOnScreen` | Codable geometry struct (`x, top, width, height, collapsed`) plus the off-screen rescue. |
| `JSONStore<T>` | `Store` in `Model.swift` | Generic over `Codable`; folder + file name are parameters. Keeps the "back up unreadable file, never overwrite" behavior and atomic writes. |
| `SaveScheduler` | `scheduleSave` / `saveNow` in `AppDelegate` | Debounced save (0.6 s) calling a closure; `flush()` on quit. |
| `DesktopApp` (lifecycle + optional status item) | `main.swift`, `AppDelegate` menu code | Accessory activation policy. Menu-bar icon only if the app asks for one; standard items (Preferences…, Open at Login, Show Data in Finder, Quit) are opt-in per app. Widget adds its own items at the top. |
| `LaunchAtLogin` | `toggleLaunchAtLogin` | Wraps `SMAppService.mainApp`, including the error alert. |
| `PreferencesWindow` + form helpers | `PrefsWindow`, `label/hint/row/numberField` in `Preferences.swift` | Framework owns the window (⌘W, edit shortcuts, activates app, centers) and a grid builder. Widget supplies its rows and places the shared "Arranging: snapping" row where it wants it (`form.addSnappingRow()`). |
| `WidgetTheme`, `swatch()` | `NoteColor.body/header/swatch` | Theme is a plain struct (`body`, `header`, `border`). Stickies keeps `NoteColor` and maps it to a theme. |
| `DesktopSettings` | `Prefs.snapping` | Framework-level settings (snapping). Same `UserDefaults` key `"snapping"` so existing values carry over. |
| Build + bundle script | `build.sh`, `Info.plist` | Shared script that wraps a SwiftPM executable into a signed `.app` and optionally installs it. |

**Stays in the widget (not framework):** the text view and all rich-text
formatting, find bar, font/text-color prefs, note colors, the delete
confirmation, "first line as title", color menu, "use this size for new notes".

---

## 2. Packaging

SwiftPM, because it gives a real module boundary (`public` API) and builds with
the Command Line Tools alone — no Xcode project needed.

```
desktop-framework/
  Package.swift                 // library "DesktopKit", macOS 14, Swift 5 language mode
  Sources/DesktopKit/
    App/DesktopApp.swift        // lifecycle, status item, standard menu items
    App/LaunchAtLogin.swift
    Window/DesktopPanel.swift
    Window/WidgetWindow.swift   // chrome + move/resize/collapse
    Window/ChromeViews.swift    // HeaderBarView, ResizeGripView, trackDrag
    Window/WidgetTheme.swift
    Layout/Snapper.swift        // pure geometry + SnapFeedback
    Layout/WidgetFrame.swift    // Codable geometry + fitOnScreen
    Layout/WidgetRegistry.swift // all live WidgetWindows in the app
    Storage/JSONStore.swift
    Storage/SaveScheduler.swift
    Settings/DesktopSettings.swift
    Preferences/PreferencesWindow.swift
    Preferences/FormBuilder.swift
    Input/EditShortcuts.swift
  Tests/DesktopKitTests/
    SnapperTests.swift          // Swift Testing (available in CLT; XCTest is not)
    JSONStoreTests.swift
    WidgetFrameTests.swift
  Scripts/bundle-app.sh
```

Widgets depend on it by local path:
`.package(path: "../desktop-framework")`.

**One app per widget** (not one host app running many widgets). It matches what
exists, keeps each widget independently installable/quittable, and avoids
designing a plugin system before there's a second widget. Revisit if running
several widget apps gets annoying (several menu-bar icons is the main cost).

---

## 3. Public API sketch

Kept deliberately small; names can change during implementation.

### App entry

```swift
// widget's main.swift
DesktopApp.run(StickiesApp())

public struct DesktopAppInfo {
    var name: String                             // "Desktop Notes"
    var statusItem: StatusItemConfig?            // nil = no menu-bar icon at all
}

public struct StatusItemConfig {
    var symbolName: String                       // SF Symbol
    var standardItems: StandardMenuItems = .all  // [.preferences, .openAtLogin, .revealData, .quit]
    var revealDataTitle = "Show Data in Finder"
}

public protocol DesktopWidgetApp: AnyObject {
    var info: DesktopAppInfo { get }
    func didLaunch()                             // create/restore windows
    func willTerminate()                         // flush saves (default: nothing)
    func statusMenuItems() -> [NSMenuItem]       // widget items, shown above the standard ones (default: [])
    var preferencesPane: PreferencesPane? { get } // nil = no Preferences window (default)
    var dataFileURL: URL? { get }                // for "Show Data in Finder"; nil hides it (default)
}

public protocol PreferencesPane: AnyObject {
    func build(_ form: PreferencesForm)          // add rows once, when the window is first made
    func refresh()                               // on show and on host.refreshPreferences()
    func preferencesDidBecomeKey()               // default: nothing
}

public final class DesktopHost {                 // DesktopApp.host
    public func openPreferences()
    public func refreshPreferences()             // was PreferencesController.notesChanged()
}
```

### Windows

```swift
public struct WidgetWindowOptions {
    var minSize: NSSize
    var headerHeight: CGFloat = 22
    var resizable = true
    var collapsible = true
    var appearance: NSAppearance? = NSAppearance(named: .aqua)
}

public protocol WidgetWindowDelegate: AnyObject {
    func widgetWindowFrameDidChange(_ w: WidgetWindow)          // move/resize/collapse → schedule save
    func widgetWindowMenu(_ w: WidgetWindow) -> NSMenu?         // header right-click
    func widgetWindowCollapsedTitle(_ w: WidgetWindow) -> String?
    func widgetWindow(_ w: WidgetWindow, keyEquivalent e: NSEvent) -> Bool   // ⌘B, ⌘N, …
    func widgetWindowPreferredSizes(_ w: WidgetWindow) -> [NSSize]           // extra snap sizes (e.g. default note size)
}

public final class WidgetWindow: NSObject {
    public init(frame: WidgetFrame, theme: WidgetTheme, options: WidgetWindowOptions)
    public let panel: DesktopPanel
    public var contentView: NSView               // widget's view, laid out under the header
    public var theme: WidgetTheme
    public weak var delegate: WidgetWindowDelegate?
    public var leadingButtons: [NSButton]        // stickies: delete
    public var trailingButtons: [NSButton]       // stickies: new; collapse button is built in
    public private(set) var isCollapsed: Bool
    public func setCollapsed(_: Bool)
    public var frame: WidgetFrame { get }        // snapshot incl. expanded height while collapsed
    public var expandedSize: NSSize { get }
    public func show(); public func close(); public func focus(firstResponder: NSResponder?)
}
```

`WidgetWindow` registers itself with `WidgetRegistry` on `show()` and removes
itself on `close()`; snapping reads every other registered window from there.

### Storage

```swift
public struct JSONStore<T: Codable> {
    public init(folder: String, file: String)    // ~/Library/Application Support/<folder>/<file>
    public var fileURL: URL
    public func load() -> T?                     // backs up unreadable files, returns nil
    public func save(_ value: T)                 // atomic, pretty, sorted keys
}

public final class SaveScheduler {
    public init(delay: TimeInterval = 0.6, save: @escaping () -> Void)
    public func schedule(); public func flush()
}
```

---

## 4. Build steps (framework side)

1. **Package skeleton.** `Package.swift`, empty module, `swift build` passes.
2. **Pure pieces first** (no UI, testable): `Snapper` with parameters instead of
   globals, `WidgetFrame` + `fitOnScreen(screens:)` (inject screen rects so it's
   testable), `JSONStore`, `SaveScheduler`. Add tests.
3. **Input + chrome:** `EditShortcuts`, `trackDrag`, `HeaderBarView`, `ResizeGripView`.
4. **`DesktopPanel` + `WidgetWindow` + `WidgetRegistry`:** port `NoteController`'s
   panel config, layout, move/resize/snap, collapse. Replace every
   `AppDelegate.shared` call with a delegate call or registry lookup.
5. **`DesktopApp`:** status item, standard items, `LaunchAtLogin`, lifecycle.
6. **Preferences:** `PreferencesWindow`, `FormBuilder` (wraps the `NSGridView`
   + `label/hint/row/numberField` helpers), framework's snapping row.
7. **`Scripts/bundle-app.sh <ExecName> <Info.plist> [install]`:** runs
   `swift build -c release --arch arm64`, assembles `Build/<Name>.app`,
   ad-hoc codesigns, optional install to `/Applications` + relaunch.
8. **Sample check:** done when `dt-stickies` builds and behaves the same as
   `desktop-stickies` (see the stickies plan's checklist).

---

## 5. Decisions

- **SwiftPM package + one app per widget** (recommended above).
- **Swift 5 language mode** for now, as today. The toolchain is Swift 6.3, but
  strict concurrency on AppKit code is churn we don't need yet; everything is
  main-thread and can be marked `@MainActor` later.
- **Name:** `DesktopKit` as the module name.
- **Invisible framework (confirmed):** no UI of its own; menu-bar icon is per-app and optional.
- **dt-stickies replaces desktop-stickies (confirmed):** same names, bundle ID, and data.

---

## 6. Deferred (add when a widget needs it)

Likely needed by `dt-claude`, *not* built in v1:

- Periodic refresh / polling scheduler, with pause when asleep or locked.
- Read-only "display" widget layout helpers (stat rows, progress bars, sparkline).
- Single-instance widget convenience (restore one window, no add/delete).
- Network / file-watching data sources, error and "stale data" states.
- Dark/translucent themes (vibrancy) alongside the pastel solid ones.
- Status-item text/badge (show a number in the menu bar).
- Per-widget-instance settings UI in the preferences window.
- A single host app running several widget kinds.
- Hotkeys, notifications, multiple-display placement rules.

---

## Status (2026-11-24)

Steps 1–7 done. DesktopKit builds with no warnings, and 11 tests pass
(`Scripts/test.sh`) covering snapping, frame rescue, and the JSON store.
`dt-stickies` is the first app built on it. Step 8 (the parity check) is a
hands-on test.
