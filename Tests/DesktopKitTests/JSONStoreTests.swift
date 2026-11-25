import Foundation
import Testing
@testable import DesktopKit

struct JSONStoreTests {
    func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("DesktopKitTests-\(UUID().uuidString)")
    }

    @Test func missingFileLoadsNil() {
        let store = JSONStore<[Int]>(fileURL: tempDir().appendingPathComponent("x.json"))
        #expect(store.load() == nil)
    }

    @Test func savesAndLoads() {
        let store = JSONStore<[String]>(fileURL: tempDir().appendingPathComponent("x.json"))
        store.save(["a", "b"])
        #expect(store.load() == ["a", "b"])
    }

    @Test func unreadableFileIsBackedUpNotLost() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("notes.json")
        let store = JSONStore<[Int]>(fileURL: url)
        try Data("not json".utf8).write(to: url)
        #expect(store.load() == nil)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.contains { $0.hasPrefix("notes.unreadable-") && $0.hasSuffix(".json") })
        #expect(try String(contentsOf: url, encoding: .utf8) == "not json")
    }
}
