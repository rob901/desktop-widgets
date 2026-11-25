import AppKit

/// Builds a two-column preferences layout: right-aligned labels, controls on the right.
public final class PreferencesForm {
    public enum RowAlignment {
        case firstBaseline   // text-like controls
        case center          // color wells, previews, other non-text views
    }

    private struct Row {
        var label: String?
        var view: NSView
        var topPadding: CGFloat
        var alignment: RowAlignment
    }

    private var rows: [Row] = []
    private var snappingToggle: SnappingToggle?

    init() {}

    /// Adds a row. `label` nil leaves the label column empty.
    public func addRow(_ label: String?, _ view: NSView, topPadding: CGFloat = 0,
                       alignment: RowAlignment = .firstBaseline) {
        rows.append(Row(label: label, view: view, topPadding: topPadding, alignment: alignment))
    }

    /// Adds small grey explanatory text under the previous row.
    public func addHint(_ text: String) {
        addRow(nil, Self.hint(text), topPadding: -4)
    }

    /// Adds the framework's shared "Arranging" row: the snapping on/off setting.
    public func addSnappingRow(topPadding: CGFloat = 12, itemName: String = "widgets") {
        let toggle = SnappingToggle()
        snappingToggle = toggle
        let checkbox = NSButton(checkboxWithTitle: "Snap to other \(itemName) and screen edges when moving or resizing",
                                target: toggle, action: #selector(SnappingToggle.changed(_:)))
        checkbox.state = DesktopSettings.snapping ? .on : .off
        addRow("Arranging:", checkbox, topPadding: topPadding)
        let singular = itemName.hasSuffix("s") ? String(itemName.dropLast()) : itemName
        addHint("Hold ⌘ while dragging to place a \(singular) freely.")
    }

    func makeGrid() -> NSGridView {
        let grid = NSGridView(views: rows.map { row in
            [row.label.map(Self.label) ?? NSGridCell.emptyContentView, row.view]
        })
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 10
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        for (i, row) in rows.enumerated() {
            let r = grid.row(at: i)
            r.topPadding = row.topPadding
            if row.alignment == .center {
                r.rowAlignment = .none
                r.yPlacement = .center
            }
        }
        return grid
    }

    // MARK: Control helpers

    public static func label(_ s: String) -> NSTextField { NSTextField(labelWithString: s) }

    public static func hint(_ s: String) -> NSTextField {
        let t = NSTextField(wrappingLabelWithString: s)
        t.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        t.textColor = .secondaryLabelColor
        t.preferredMaxLayoutWidth = 400
        return t
    }

    /// Controls side by side, aligned on their text baselines.
    public static func hstack(_ views: [NSView]) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.alignment = .firstBaseline
        s.spacing = 6
        return s
    }

    /// Configures a right-aligned whole-number field of a fixed width.
    public static func numberField(_ field: NSTextField, target: AnyObject, action: Selector, width: CGFloat) {
        let f = NumberFormatter()
        f.allowsFloats = false
        f.minimum = 1
        field.formatter = f
        field.alignment = .right
        field.target = target
        field.action = action
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
    }
}

private final class SnappingToggle: NSObject {
    @objc func changed(_ sender: NSButton) { DesktopSettings.snapping = sender.state == .on }
}
