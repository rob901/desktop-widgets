import Foundation

/// Reads and writes one Codable value as a JSON file.
/// A file that exists but can't be decoded is copied aside, never silently overwritten.
public struct JSONStore<Value: Codable> {
    public let fileURL: URL

    /// A file in `~/Library/Application Support/<folder>/<file>`.
    public init(folder: String, file: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folder, isDirectory: true)
        self.init(fileURL: dir.appendingPathComponent(file))
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
    }

    /// The saved value, or nil if there is no file or it couldn't be read.
    public func load() -> Value? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let name = fileURL.deletingPathExtension().lastPathComponent
            let ext = fileURL.pathExtension.isEmpty ? "" : ".\(fileURL.pathExtension)"
            let backup = fileURL.deletingLastPathComponent().appendingPathComponent("\(name).unreadable-\(stamp)\(ext)")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            NSLog("DesktopKit: could not decode \(fileURL.path) (\(error)); backed up to \(backup.path)")
            return nil
        }
    }

    public func save(_ value: Value) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(value).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("DesktopKit: save to \(fileURL.path) failed: \(error)")
        }
    }
}
