import AppKit

public struct WidgetWindowOptions {
    public var minSize: NSSize
    public var headerHeight: CGFloat
    public var resizable: Bool
    public var collapsible: Bool
    /// Fixed appearance for the window's controls; nil follows the system.
    public var appearance: NSAppearance?

    public init(minSize: NSSize = NSSize(width: 130, height: 70),
                headerHeight: CGFloat = 22,
                resizable: Bool = true,
                collapsible: Bool = true,
                appearance: NSAppearance? = NSAppearance(named: .aqua)) {
        self.minSize = minSize
        self.headerHeight = headerHeight
        self.resizable = resizable
        self.collapsible = collapsible
        self.appearance = appearance
    }
}

public protocol WidgetWindowDelegate: AnyObject {
    /// The window moved, resized, or collapsed/expanded. Typically: schedule a save.
    func widgetWindowDidChangeFrame(_ window: WidgetWindow)
    /// Text shown in the header while collapsed.
    func widgetWindowCollapsedTitle(_ window: WidgetWindow) -> String?
    /// Menu for right-clicking the header.
    func widgetWindowMenu(_ window: WidgetWindow) -> NSMenu?
    /// First look at key equivalents while the window is key. Return true if handled.
    func widgetWindow(_ window: WidgetWindow, performKeyEquivalent event: NSEvent) -> Bool
    /// Extra sizes to snap to when resizing (e.g. the default size for new widgets).
    func widgetWindowSnapSizes(_ window: WidgetWindow) -> [NSSize]
}

public extension WidgetWindowDelegate {
    func widgetWindowDidChangeFrame(_ window: WidgetWindow) {}
    func widgetWindowCollapsedTitle(_ window: WidgetWindow) -> String? { nil }
    func widgetWindowMenu(_ window: WidgetWindow) -> NSMenu? { nil }
    func widgetWindow(_ window: WidgetWindow, performKeyEquivalent event: NSEvent) -> Bool { false }
    func widgetWindowSnapSizes(_ window: WidgetWindow) -> [NSSize] { [] }
}

/// A desktop widget window: a `DesktopPanel` with a header bar (drag to move,
/// double-click to collapse, right-click for a menu), optional resize corner,
/// snapping, and a content area the widget fills with its own view.
public final class WidgetWindow: NSObject, NSWindowDelegate {
    public let panel: DesktopPanel
    public let options: WidgetWindowOptions

    public weak var delegate: WidgetWindowDelegate? { didSet { refreshTitle() } }

    public var theme: WidgetTheme { didSet { applyTheme() } }

    /// The widget's own view, laid out below the header.
    public var contentView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let contentView { container.addSubview(contentView, positioned: .below, relativeTo: grip) }
            applyCollapsedState()
            layout()
        }
    }

    /// Buttons at the left end of the header (see `makeHeaderButton`).
    public var leadingButtons: [NSButton] = [] {
        didSet { replaceHeaderButtons(old: oldValue, new: leadingButtons) }
    }

    /// Buttons at the right end of the header, before the built-in collapse button.
    public var trailingButtons: [NSButton] = [] {
        didSet { replaceHeaderButtons(old: oldValue, new: trailingButtons) }
    }

    public private(set) var isCollapsed: Bool
    private var expandedHeight: CGFloat

    private let container = WidgetContainerView()
    private let header = HeaderBarView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let collapseButton = WidgetWindow.makeHeaderButton(symbol: "chevron.up", toolTip: "Collapse",
                                                               target: nil, action: nil)
    private let grip = ResizeGripView()

    public init(frame: WidgetFrame, theme: WidgetTheme, options: WidgetWindowOptions = WidgetWindowOptions()) {
        self.options = options
        self.theme = theme
        isCollapsed = options.collapsible && frame.collapsed
        expandedHeight = max(CGFloat(frame.height), options.minSize.height)

        let height = isCollapsed ? options.headerHeight : expandedHeight
        let rect = NSRect(x: frame.x, y: frame.top - Double(height), width: frame.width, height: Double(height))
        panel = DesktopPanel(contentRect: rect)
        super.init()

        panel.appearance = options.appearance
        panel.delegate = self
        panel.keyEquivalentHandler = { [weak self] event in
            guard let self, let delegate = self.delegate else { return false }
            return delegate.widgetWindow(self, performKeyEquivalent: event)
        }

        configureHeader()
        configureGrip()
        container.onResize = { [weak self] in self?.layout() }
        container.addSubview(grip)
        container.addSubview(header)
        panel.contentView = container
        applyTheme()
        applyCollapsedState()
        layout()
    }

    // MARK: Geometry

    /// The window's size when expanded, even if it's collapsed right now.
    public var expandedSize: NSSize {
        NSSize(width: panel.frame.width, height: isCollapsed ? expandedHeight : panel.frame.height)
    }

    /// Current geometry, for saving.
    public var frame: WidgetFrame {
        let f = panel.frame
        return WidgetFrame(x: f.minX, top: f.maxY, width: f.width,
                           height: isCollapsed ? expandedHeight : f.height, collapsed: isCollapsed)
    }

    // MARK: Showing

    /// Puts the window on screen and registers it for snapping.
    public func show() {
        WidgetRegistry.shared.add(self)
        panel.orderFront(nil)
    }

    /// Takes the window off screen and unregisters it.
    public func close() {
        panel.orderOut(nil)
        WidgetRegistry.shared.remove(self)
    }

    /// Brings the window forward, makes it key, and (if expanded) focuses `responder`.
    public func focus(_ responder: NSResponder? = nil) {
        panel.orderFront(nil)
        panel.makeKey()
        if !isCollapsed, let responder { panel.makeFirstResponder(responder) }
    }

    // MARK: Collapse

    public func toggleCollapsed() { setCollapsed(!isCollapsed) }

    /// Collapses to just the header (or expands), keeping the top edge in place.
    public func setCollapsed(_ value: Bool) {
        guard options.collapsible, value != isCollapsed else { return }
        var f = panel.frame
        let top = f.maxY
        if value { expandedHeight = f.height }
        isCollapsed = value
        f.size.height = value ? options.headerHeight : expandedHeight
        f.origin.y = top - f.height
        panel.setFrame(f, display: true, animate: false)
        applyCollapsedState()
        delegate?.widgetWindowDidChangeFrame(self)
    }

    /// Re-asks the delegate for the collapsed title.
    public func refreshTitle() {
        titleLabel.stringValue = isCollapsed ? (delegate?.widgetWindowCollapsedTitle(self) ?? "") : ""
    }

    private func applyCollapsedState() {
        contentView?.isHidden = isCollapsed
        grip.isHidden = isCollapsed || !options.resizable
        collapseButton.isHidden = !options.collapsible
        collapseButton.image = NSImage(systemSymbolName: isCollapsed ? "chevron.down" : "chevron.up",
                                       accessibilityDescription: isCollapsed ? "Expand" : "Collapse")
        collapseButton.toolTip = isCollapsed ? "Expand (double-click the bar)" : "Collapse (double-click the bar)"
        refreshTitle()
        if isCollapsed, let contentView, let responder = panel.firstResponder as? NSView,
           responder.isDescendant(of: contentView) {
            panel.makeFirstResponder(nil)
        }
    }

    // MARK: Header buttons

    /// A small borderless SF Symbol button styled for the header.
    public static func makeHeaderButton(symbol: String, toolTip: String, target: AnyObject?, action: Selector?) -> NSButton {
        let b = NSButton()
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: toolTip)
        b.symbolConfiguration = .init(pointSize: 9, weight: .bold)
        b.isBordered = false
        b.imagePosition = .imageOnly
        b.toolTip = toolTip
        b.target = target
        b.action = action
        return b
    }

    private func replaceHeaderButtons(old: [NSButton], new: [NSButton]) {
        old.forEach { $0.removeFromSuperview() }
        new.forEach {
            $0.contentTintColor = theme.buttonTint
            header.addSubview($0)
        }
        layout()
    }

    private var allTrailingButtons: [NSButton] {
        trailingButtons + (options.collapsible ? [collapseButton] : [])
    }

    // MARK: Setup

    private func configureHeader() {
        header.onDoubleClick = { [weak self] in self?.toggleCollapsed() }
        header.menuProvider = { [weak self] in
            guard let self else { return nil }
            return self.delegate?.widgetWindowMenu(self)
        }

        var startOrigin = NSPoint.zero
        var feedback = SnapFeedback()
        var context: Snapper.Context?
        header.onDrag = { [weak self] delta in
            guard let self else { return }
            if context == nil {
                startOrigin = self.panel.frame.origin
                context = self.snapContext()
            }
            var f = self.panel.frame
            f.origin = NSPoint(x: startOrigin.x + delta.x, y: startOrigin.y + delta.y)
            if !Snapper.bypassed, let context {
                let snap = Snapper.move(f, in: context)
                f.origin = snap.origin
                feedback.update(snap.snappedX, snap.snappedY)
            } else {
                feedback.update(nil, nil)
            }
            self.panel.setFrameOrigin(f.origin)
        }
        header.onDragEnded = {
            context = nil
            feedback = SnapFeedback()
        }

        collapseButton.target = self
        collapseButton.action = #selector(collapseClicked)

        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.truncatesLastVisibleLine = true

        header.addSubview(titleLabel)
        header.addSubview(collapseButton)
    }

    @objc private func collapseClicked() { toggleCollapsed() }

    private func configureGrip() {
        var startFrame = NSRect.zero
        var feedback = SnapFeedback()
        var context: Snapper.Context?
        grip.onDrag = { [weak self] delta in
            guard let self else { return }
            if context == nil {
                startFrame = self.panel.frame
                context = self.snapContext()
            }
            let min = self.options.minSize
            var f = startFrame
            f.size.width = max(min.width, startFrame.width + delta.x)
            f.size.height = max(min.height, startFrame.height - delta.y)
            if !Snapper.bypassed, let context {
                let snap = Snapper.resize(f, in: context)
                f.size = snap.size
                feedback.update(snap.snappedW, snap.snappedH)
            } else {
                feedback.update(nil, nil)
            }
            f.origin.y = startFrame.maxY - f.height   // keep the top edge pinned
            self.panel.setFrame(f, display: true)
        }
        grip.onDragEnded = { [weak self] in
            context = nil
            feedback = SnapFeedback()
            if let self { self.delegate?.widgetWindowDidChangeFrame(self) }
        }
    }

    private func snapContext() -> Snapper.Context {
        let others = WidgetRegistry.shared.windows.filter { $0 !== self }
        return Snapper.Context(frames: others.map { $0.panel.frame },
                               sizes: others.map { $0.expandedSize } + (delegate?.widgetWindowSnapSizes(self) ?? []),
                               screens: NSScreen.screens.map { $0.visibleFrame },
                               minSize: options.minSize)
    }

    private func applyTheme() {
        container.wantsLayer = true
        container.layer?.backgroundColor = theme.body.cgColor
        container.layer?.borderColor = theme.border.cgColor
        container.layer?.borderWidth = 0.5
        header.fill = theme.header
        panel.backgroundColor = theme.body
        titleLabel.textColor = theme.title
        for b in leadingButtons + allTrailingButtons { b.contentTintColor = theme.buttonTint }
    }

    // MARK: Layout

    private func layout() {
        let bounds = container.bounds
        let h = options.headerHeight
        header.frame = NSRect(x: 0, y: bounds.height - h, width: bounds.width, height: h)
        contentView?.frame = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - h))
        grip.frame = NSRect(x: bounds.width - 14, y: 0, width: 14, height: 14)

        let s: CGFloat = 18, y = (h - s) / 2, step = s + 2
        var x: CGFloat = 3
        for b in leadingButtons {
            b.frame = NSRect(x: x, y: y, width: s, height: s)
            x += step
        }
        let trailing = allTrailingButtons
        var right = bounds.width - s - 3
        for b in trailing.reversed() {
            b.frame = NSRect(x: right, y: y, width: s, height: s)
            right -= step
        }
        let titleX = 4 + CGFloat(leadingButtons.count) * step
        let titleRight = bounds.width - 2 - CGFloat(trailing.count + 1) * step
        titleLabel.frame = NSRect(x: titleX, y: (h - 15) / 2, width: max(0, titleRight - titleX), height: 15)
    }

    // MARK: NSWindowDelegate

    public func windowDidMove(_ notification: Notification) { delegate?.widgetWindowDidChangeFrame(self) }
    public func windowDidResize(_ notification: Notification) { delegate?.widgetWindowDidChangeFrame(self) }
}
