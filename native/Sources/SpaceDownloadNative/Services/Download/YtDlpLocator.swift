import Foundation

struct ToolLocations: Equatable {
    let ytDlp: URL
    let ffmpeg: URL?
}

enum YtDlpLocator {
    static func locate(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> ToolLocations? {
        guard let ytDlp = firstExecutable(
            named: "yt-dlp",
            bundle: bundle,
            environment: environment,
            fileManager: fileManager
        ) else {
            return nil
        }
        let ffmpeg = firstExecutable(
            named: "ffmpeg",
            bundle: bundle,
            environment: environment,
            fileManager: fileManager
        )
        return ToolLocations(ytDlp: ytDlp, ffmpeg: ffmpeg)
    }

    private static func firstExecutable(
        named name: String,
        bundle: Bundle,
        environment: [String: String],
        fileManager: FileManager
    ) -> URL? {
        var candidates: [URL] = []
        if let resourceURL = bundle.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(name))
        }
        candidates.append(contentsOf: [
            URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"),
            URL(fileURLWithPath: "/usr/local/bin/\(name)"),
            URL(fileURLWithPath: "/usr/bin/\(name)"),
        ])
        for directory in (environment["PATH"] ?? "").split(separator: ":") {
            candidates.append(URL(fileURLWithPath: String(directory)).appendingPathComponent(name))
        }
        return candidates.first { fileManager.isExecutableFile(atPath: $0.path) }
    }
}
