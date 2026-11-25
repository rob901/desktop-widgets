import AppKit

/// Desktop widgets never make their app frontmost, so there is no active menu bar
/// to provide the standard editing shortcuts. Windows call this instead.
public func performStandardEditShortcut(_ event: NSEvent, from sender: Any?) -> Bool {
    guard event.type == .keyDown, let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
    let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
    var action: String?
    if flags == .command {
        action = ["x": "cut:", "c": "copy:", "v": "paste:", "a": "selectAll:", "z": "undo:"][key]
    } else if flags == [.command, .shift], key == "z" {
        action = "redo:"
    }
    guard let action else { return false }
    return NSApp.sendAction(Selector(action), to: nil, from: sender)
}
