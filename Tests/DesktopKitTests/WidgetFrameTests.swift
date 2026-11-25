import AppKit
import Testing
@testable import DesktopKit

struct WidgetFrameTests {
    let main = NSRect(x: 0, y: 0, width: 1000, height: 800)

    @Test func onScreenFrameIsUnchanged() {
        let f = WidgetFrame(x: 100, top: 500, width: 200, height: 150)
        #expect(f.fittedOnScreen(visibleFrames: [main], fallback: main) == f)
    }

    @Test func offScreenFrameMovesToCenterOfFallback() {
        let f = WidgetFrame(x: 3000, top: 500, width: 200, height: 150, collapsed: true)
        let fitted = f.fittedOnScreen(visibleFrames: [main], fallback: main)
        #expect(fitted.x == 400)
        #expect(fitted.top == 475)
        #expect(fitted.width == 200 && fitted.height == 150 && fitted.collapsed)
    }

    @Test func roundTripsThroughJSON() throws {
        let f = WidgetFrame(x: 1, top: 2, width: 3, height: 4, collapsed: true)
        let decoded = try JSONDecoder().decode(WidgetFrame.self, from: JSONEncoder().encode(f))
        #expect(decoded == f)
    }
}
