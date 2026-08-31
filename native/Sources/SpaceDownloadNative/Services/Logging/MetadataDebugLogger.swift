import Foundation

protocol MetadataDebugLogging {
    func write(metadata: [String: Any], label: String) throws -> URL
}

struct MetadataDebugLogger: MetadataDebugLogging {
    private let directoryURL: URL

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/SpaceDownload", isDirectory: true)
    }

    func write(metadata: [String: Any], label: String) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("metadata.log")
        let data = try JSONSerialization.data(
            withJSONObject: metadata,
            options: [.prettyPrinted, .sortedKeys]
        )
        let json = String(decoding: data, as: UTF8.self)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "\n===== \(timestamp) | \(label) =====\n\(json)\n"
        let entryData = Data(entry.utf8)

        if !fileManager.fileExists(atPath: fileURL.path) {
            try entryData.write(to: fileURL, options: .atomic)
            return fileURL
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: entryData)
        return fileURL
    }
}

struct DisabledMetadataDebugLogger: MetadataDebugLogging {
    func write(metadata: [String: Any], label: String) throws -> URL {
        URL(fileURLWithPath: "/dev/null")
    }
}
