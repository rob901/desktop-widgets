import Foundation

/// Coalesces bursts of changes into one save a moment after the last change.
public final class SaveScheduler {
    private let delay: TimeInterval
    private let save: () -> Void
    private var timer: Timer?

    public init(delay: TimeInterval = 0.6, save: @escaping () -> Void) {
        self.delay = delay
        self.save = save
    }

    public func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.flush()
        }
    }

    /// Saves now, cancelling any pending save.
    public func flush() {
        timer?.invalidate()
        timer = nil
        save()
    }
}
