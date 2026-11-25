# DesktopKit

A Swift library for macOS desktop widgets: windows that sit just above the desktop
icons, behind every app, on every Space, and stay usable during Show Desktop.

DesktopKit has no app or UI of its own. Each widget is its own app that depends on
it, and each app decides whether it has a menu-bar icon.

## What it provides

- `DesktopApp.run(app)`: lifecycle, an optional menu-bar icon (`DesktopAppInfo.statusItem`; nil means none),
  standard menu items you can turn on (Preferences…, Open at Login, Show data in Finder, Quit).
- `WidgetWindow`: a desktop panel with a header bar (drag to move, double-click to collapse,
  right-click menu, your buttons), a resize corner, and snapping. You supply `contentView`.
- `JSONStore<T>` + `SaveScheduler`: JSON persistence with debounced saves; unreadable files are backed up, never overwritten.
- `WidgetFrame`: Codable geometry, with a rescue for windows saved on a missing display.
- `PreferencesPane` + `PreferencesForm`: a preferences window where you add the rows.
- `LaunchAtLogin`, `DesktopSettings`, `performStandardEditShortcut`.

## Using it

```swift
// Package.swift
.package(path: "../desktop-framework")
// target dependency
.product(name: "DesktopKit", package: "desktop-framework")
```

Build a widget app into a signed `.app`:

```sh
Scripts/bundle-app.sh <package-dir> <ExecutableName> [install]
```

The package dir needs an `Info.plist` with `LSUIElement` = true and
`CFBundleExecutable` = the executable name. See `../dt-stickies` for a complete app.

## Tests

```sh
Scripts/test.sh   # works with only the Command Line Tools installed
```

See `PLAN.md` for the design and what's deferred.
