import AppKit

/// Runs an action on a fixed interval, and again right after the Mac wakes from sleep.
/// Fires during menu tracking too. Use it to refresh a widget's data and redraw.
public final class PeriodicTask {
    private let interval: TimeInterval
    private let action: () -> Void
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    public init(interval: TimeInterval, action: @escaping () -> Void) {
        self.interval = interval
        self.action = action
    }

    public func start(fireImmediately: Bool = true) {
        stop()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.action() }
        t.tolerance = interval * 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.action() }
        if fireImmediately { action() }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
    }

    /// Runs the action now, outside the schedule.
    public func fire() { action() }

    deinit { stop() }
}
