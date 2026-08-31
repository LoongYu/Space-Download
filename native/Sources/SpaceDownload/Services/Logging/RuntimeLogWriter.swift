import Foundation

protocol RuntimeLogWriting {
    func append(_ line: String)
}

final class RuntimeLogWriter: RuntimeLogWriting {
    private let fileURL: URL
    private let lock = NSLock()

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        let defaultDirectory = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Logs/SpaceDownload", isDirectory: true)
        let resolvedURL = fileURL ?? defaultDirectory.appendingPathComponent("app.log")
        self.fileURL = resolvedURL
        try? fileManager.createDirectory(
            at: resolvedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    func append(_ line: String) {
        lock.withLock {
            guard let data = (line + "\n").data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: fileURL.path),
               let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } catch {
                    return
                }
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }
}

struct DisabledRuntimeLogWriter: RuntimeLogWriting {
    func append(_ line: String) {}
}
