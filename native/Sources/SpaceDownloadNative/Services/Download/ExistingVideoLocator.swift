import Foundation

enum ExistingVideoLocator {
    private static let videoExtensions = Set(["mp4", "mkv", "webm", "flv", "mov", "avi"])

    static func videoID(from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for key in ["viewkey", "v", "id"] {
                if let value = components.queryItems?.first(where: { $0.name == key })?.value,
                   !value.isEmpty {
                    return value
                }
            }
        }
        let lastComponent = url.deletingPathExtension().lastPathComponent
        let genericComponents = Set(["video", "videos", "view_video", "watch"])
        guard lastComponent.count >= 6,
              !genericComponents.contains(lastComponent.lowercased())
        else { return nil }
        return lastComponent
    }

    static func find(videoID: String, in directory: URL, fileManager: FileManager = .default) -> URL? {
        guard !videoID.isEmpty,
              let enumerator = fileManager.enumerator(
                  at: directory,
                  includingPropertiesForKeys: [.isRegularFileKey],
                  options: [.skipsHiddenFiles]
              )
        else { return nil }

        for case let fileURL as URL in enumerator {
            guard videoExtensions.contains(fileURL.pathExtension.lowercased()),
                  fileURL.deletingPathExtension().lastPathComponent.contains(videoID)
            else { continue }
            return fileURL
        }
        return nil
    }
}
