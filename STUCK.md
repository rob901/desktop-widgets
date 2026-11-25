# Stuck — the DesktopKit console (notes for later)

**Status:** not started. These are notes collected while building the first widgets,
to plan the framework's own management app.

## The idea

Launching **Stuck** opens one window that:

1. Lists every installed app built on DesktopKit (running or not), with its icon, name, and version.
2. Opens any app's own preferences from there.
3. Holds the framework-wide preferences (today only snapping) in one place, instead of per app.
4. Probably: launch/quit apps, toggle Open at Login, show/hide all widgets.

Stuck is part of the framework repo, but it is a separate app product. DesktopKit itself
stays invisible.

## What the widgets look like today (constraints Stuck has to fit)

| App | Menu-bar icon | Windows | Where its controls are |
|---|---|---|---|
| Desktop Notes (`dt-stickies`) | yes | many notes | status menu + note right-click |
| Claude Usage (`dt-claude`) | **no** | one | widget right-click menu only |

- Each app is a separate process with its own bundle ID and its own `UserDefaults`.
- Apps without a menu-bar icon can only be reached through their widget's right-click menu.
  This is the main thing Stuck fixes: a collapsed or hidden widget has no other way in.
- Preferences windows are built by the framework (`PreferencesController`) from the app's
  `PreferencesPane`. Stuck can't host another process's views, so "open app preferences"
  means asking that app to show its own window.
- Framework settings (`DesktopSettings.snapping`) are currently stored in each app's own
  defaults. So snapping is per app today, though every app shows the same checkbox.

## Pieces the framework will need

1. **Discovery: an app registry.** At launch, `DesktopHost` writes a manifest to
   `~/Library/Application Support/DesktopKit/apps/<bundle-id>.json`:
   name, bundle ID, bundle path, version, framework version, `hasPreferences`,
   `hasStatusItem`, data file path, last launch time.
   Stuck reads the folder and drops entries whose bundle path no longer exists.
   (Alternative: Spotlight query for apps whose Info.plist has a `DesktopKitApp` key.
   Spotlight finds apps that never launched, but it's less dependable.)
2. **Commands: Stuck → app.** Use `DistributedNotificationCenter` with names like
   `local.desktopkit.command.<bundle-id>`, payload `{command: "openPreferences" | "showWidgets" | "quit" | "reloadSettings"}`.
   If the app isn't running, launch it with `NSWorkspace.openApplication(at:configuration:)`
   and pass the command as a launch argument (e.g. `--open-preferences`).
   Another option is a URL scheme per app (`desktopkit-<id>://preferences`), but that needs
   an Info.plist entry in every app.
3. **Shared framework settings.** Move `DesktopSettings` to a shared defaults suite, e.g.
   `UserDefaults(suiteName: "local.desktopkit.shared")`. That works for unsandboxed apps
   signed ad hoc; sandboxing would need an App Group. When a setting changes, post a distributed
   notification so running apps re-read it. Migration: on first run, copy the app's own
   `snapping` value if the shared one isn't set.
4. **Status reporting (optional).** Apps answer a `ping` notification with
   `{running, windowCount, collapsedCount}` so Stuck can show live state.
5. **Embeddable preference rows (maybe later).** If Stuck should show app preferences inline,
   panes would need a description of their settings in data form (key, type, label, range)
   instead of AppKit views. Only worth it if opening each app's own window feels clunky.

## Open questions

- Should Stuck have a menu-bar icon of its own? That would replace per-app icons for widgets that opt out.
- Should Stuck be the only thing in Open at Login, launching the widget apps itself?
- Distribution: today every app is ad-hoc signed and copied to `/Applications` by `bundle-app.sh`.
  Stuck could find apps in `/Applications` by that marker.
