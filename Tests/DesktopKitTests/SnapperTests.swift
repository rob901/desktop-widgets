import AppKit
import Testing
@testable import DesktopKit

struct SnapperTests {
    let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
    let min = NSSize(width: 130, height: 70)

    @Test func snapsToScreenEdgeWithinThreshold() {
        let c = Snapper.Context(frames: [], sizes: [], screens: [screen], minSize: min)
        let r = Snapper.move(NSRect(x: 5, y: 300, width: 200, height: 100), in: c)
        #expect(r.origin.x == 0)
        #expect(r.snappedX == 0)
        #expect(r.snappedY == nil)
    }

    @Test func ignoresEdgesBeyondThreshold() {
        let c = Snapper.Context(frames: [], sizes: [], screens: [screen], minSize: min)
        let r = Snapper.move(NSRect(x: 20, y: 300, width: 200, height: 100), in: c)
        #expect(r.origin.x == 20)
        #expect(r.snappedX == nil)
    }

    @Test func sitsBesideAnotherWidget() {
        let other = NSRect(x: 100, y: 300, width: 200, height: 100)
        let c = Snapper.Context(frames: [other], sizes: [], screens: [], minSize: min)
        let r = Snapper.move(NSRect(x: 305, y: 320, width: 150, height: 100), in: c)
        #expect(r.origin.x == 300)
    }

    @Test func resizeSnapsToPreferredSize() {
        let c = Snapper.Context(frames: [], sizes: [NSSize(width: 240, height: 220)], screens: [], minSize: min)
        let r = Snapper.resize(NSRect(x: 100, y: 100, width: 244, height: 215), in: c)
        #expect(r.size == NSSize(width: 240, height: 220))
    }

    @Test func resizeNeverSnapsBelowMinimum() {
        let c = Snapper.Context(frames: [], sizes: [NSSize(width: 125, height: 65)], screens: [], minSize: min)
        let r = Snapper.resize(NSRect(x: 100, y: 100, width: 130, height: 70), in: c)
        #expect(r.snappedW == nil)
        #expect(r.snappedH == nil)
    }
}
