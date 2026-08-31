import Foundation

struct YouTubeAdapter: SiteAdapter {
    let siteID: SiteID? = .youtube
    let displayName = "YouTube"

    func matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "youtu.be"
            || host == "youtube.com"
            || host.hasSuffix(".youtube.com")
    }

    func classify(_ url: URL) -> SiteLinkKind {
        let path = url.path.lowercased()
        if path == "/playlist" || path.hasPrefix("/playlist/") {
            return .playlist
        }
        if path.hasPrefix("/@")
            || path.hasPrefix("/channel/")
            || path.hasPrefix("/c/")
            || path.hasPrefix("/user/") {
            return .channel
        }
        return .singleVideo
    }

    func collectionSources(for url: URL, request: DownloadRequest) -> [SiteCollectionSource] {
        let kind = classify(url)
        let scopedURL = kind == .channel
            ? channelURL(url, scope: request.settings.sites.youtube.channelScope)
            : url
        return [SiteCollectionSource(
            url: scopedURL,
            page: nil,
            label: kind == .channel ? "YouTube 频道" : "YouTube 播放列表"
        )]
    }

    func collectionArguments(for url: URL, request: DownloadRequest) -> [String] {
        guard classify(url) == .playlist else { return [] }
        guard let items = request.youtubePlaylistItems, !items.isEmpty else { return [] }
        return ["--playlist-items", items.map(String.init).joined(separator: ",")]
    }

    func networkArguments(for phase: YtDlpPhase, request: DownloadRequest) -> [String] {
        var arguments: [String] = []
        if let runtime = YouTubeJavaScriptRuntimeLocator.locate() {
            arguments += ["--js-runtimes", runtime.argument]
        }
        guard phase != .metadata else { return arguments }
        let interval = max(request.settings.sites.youtube.requestIntervalSeconds, 0)
        guard interval > 0 else { return arguments }
        if phase == .collection {
            return arguments + ["--sleep-requests", "1"]
        }
        return arguments + [
            "--sleep-interval", String(interval),
            "--max-sleep-interval", String(interval),
        ]
    }

    func downloadArguments(for request: DownloadRequest) -> [String] {
        let settings = request.settings.sites.youtube
        var arguments: [String] = []
        if let codecSort = settings.codecPreference.ytDlpSortValue {
            arguments += ["--format-sort", codecSort]
        }
        switch settings.subtitleMode {
        case .none:
            break
        case .manual:
            arguments += ["--write-subs"]
        case .manualAndAuto:
            arguments += ["--write-subs", "--write-auto-subs"]
        }
        if settings.subtitleMode != .none {
            let languages = settings.subtitleLanguages.trimmingCharacters(in: .whitespacesAndNewlines)
            if !languages.isEmpty {
                arguments += ["--sub-langs", languages]
            }
            arguments += ["--convert-subs", "srt"]
        }
        return arguments
    }

    func resolvedEntryURL(from entry: [String: Any]) -> URL? {
        for key in ["webpage_url", "original_url", "url"] {
            if let value = entry[key] as? String,
               let url = URL(string: value),
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                return url
            }
        }
        guard let id = entry["id"] as? String, !id.isEmpty else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(id)")
    }

    private func channelURL(_ url: URL, scope: YouTubeChannelScope) -> URL {
        guard scope != .all,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        let suffix: String
        switch scope {
        case .all: return url
        case .videos: suffix = "videos"
        case .shorts: suffix = "shorts"
        case .streams: suffix = "streams"
        }
        let trimmed = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let knownTabs = ["videos", "shorts", "streams", "playlists", "featured"]
        var parts = trimmed.split(separator: "/").map(String.init)
        if let last = parts.last, knownTabs.contains(last.lowercased()) {
            parts.removeLast()
        }
        parts.append(suffix)
        components.path = "/" + parts.joined(separator: "/")
        return components.url ?? url
    }
}

struct YouTubeJavaScriptRuntime: Equatable {
    let name: String
    let url: URL

    var argument: String { "\(name):\(url.path)" }
}

enum YouTubeJavaScriptRuntimeLocator {
    private static let runtimeNames = ["deno", "node", "bun", "quickjs"]
    private static let defaultDirectories = [
        URL(fileURLWithPath: "/opt/homebrew/bin"),
        URL(fileURLWithPath: "/usr/local/bin"),
        URL(fileURLWithPath: "/usr/bin"),
    ]

    static func locate(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        systemDirectories: [URL] = defaultDirectories
    ) -> YouTubeJavaScriptRuntime? {
        var directories: [URL] = []
        if let resourceURL = bundle.resourceURL {
            directories.append(resourceURL)
        }
        directories.append(contentsOf: systemDirectories)
        directories.append(contentsOf: (environment["PATH"] ?? "").split(separator: ":").map {
            URL(fileURLWithPath: String($0))
        })

        for name in runtimeNames {
            for directory in directories {
                let candidate = directory.appendingPathComponent(name)
                if fileManager.isExecutableFile(atPath: candidate.path) {
                    return YouTubeJavaScriptRuntime(name: name, url: candidate)
                }
            }
        }
        return nil
    }
}
