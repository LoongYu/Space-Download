import Foundation

struct YtDlpCommandBuilder {
    static let progressPrefix = "SPACEDOWNLOAD_PROGRESS:"
    static let resultPrefix = "SPACEDOWNLOAD_RESULT:"

    let tools: ToolLocations

    func metadataArguments(for url: URL, request: DownloadRequest) -> [String] {
        let url = SiteRegistry.adapter(for: url).canonicalURL(url)
        return commonNetworkArguments(for: url, phase: .metadata, request: request) + [
            "--no-playlist",
            "--skip-download",
            "--dump-single-json",
            url.absoluteString,
        ]
    }

    func resourceDiscoveryArguments(for url: URL, request: DownloadRequest) -> [String] {
        let url = SiteRegistry.adapter(for: url).canonicalURL(url)
        return commonNetworkArguments(for: url, phase: .metadata, request: request) + [
            "--yes-playlist",
            "--skip-download",
            "--dump-single-json",
            url.absoluteString,
        ]
    }

    func collectionArguments(for url: URL, request: DownloadRequest) -> [String] {
        let adapter = SiteRegistry.adapter(for: url)
        let url = adapter.canonicalURL(url)
        return commonNetworkArguments(for: url, phase: .collection, request: request)
            + adapter.collectionArguments(for: url, request: request) + [
            "--flat-playlist",
            "--skip-download",
            "--dump-single-json",
            url.absoluteString,
        ]
    }

    func downloadArguments(
        for item: DownloadItem,
        request: DownloadRequest,
        temporaryDirectory: URL,
        translatedTitle: String? = nil
    ) -> [String] {
        let settings = request.settings
        let adapter = SiteRegistry.adapter(for: item.url)
        let canonicalURL = adapter.canonicalURL(item.url)
        let mediaSettings = settings.mediaSettings(for: adapter.siteID)
        let concurrentFragments = min(max(settings.common.concurrentFragments, 1), 16)
        var arguments = commonNetworkArguments(for: item.url, phase: .download, request: request)
        arguments += [
            "--retries", "5",
            "--fragment-retries", "5",
            "--concurrent-fragments", String(concurrentFragments),
            "--progress",
            "--progress-delta", "0.25",
            "--socket-timeout", "30",
            "--no-part",
            "--format", settings.quality.ytDlpFormat,
            "--merge-output-format", settings.outputFormat.rawValue,
            "--recode-video", settings.outputFormat.rawValue,
            "--paths", "home:\(settings.downloadPath)",
            "--paths", "temp:\(temporaryDirectory.path)",
            "--output", "\(mediaSettings.resolvedFilenameTemplate).%(ext)s",
            "--progress-template", "download:\(Self.progressPrefix)%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print", "after_move:\(Self.resultPrefix)%()j",
        ]
        if let selector = item.resource?.selector {
            arguments += ["--yes-playlist", "--playlist-items", String(selector)]
        } else {
            arguments += ["--no-playlist"]
        }
        if let rateLimit = settings.common.rateLimit.ytDlpValue {
            arguments += ["--limit-rate", rateLimit]
        }
        arguments += adapter.downloadArguments(for: request)
        if let ffmpeg = tools.ffmpeg {
            arguments += ["--ffmpeg-location", ffmpeg.path]
        }
        if let translatedTitle, !translatedTitle.isEmpty, translatedTitle != item.title {
            arguments += [
                "--replace-in-metadata",
                "pre_process:title",
                "^.*$",
                translatedTitle.replacingOccurrences(of: "\\", with: "\\\\"),
            ]
        }
        arguments.append(canonicalURL.absoluteString)
        return arguments
    }

    private func commonNetworkArguments(
        for url: URL,
        phase: YtDlpPhase,
        request: DownloadRequest
    ) -> [String] {
        let adapter = SiteRegistry.adapter(for: url)
        var arguments = [
            "--newline",
            "--no-color",
        ]
        if adapter.siteID == .youtube {
            arguments += ["--ignore-config"]
        } else {
            arguments += [
                "--user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120 Safari/537.36",
                "--add-header", "Accept-Language:en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7",
            ]
        }
        arguments += adapter.networkArguments(for: phase, request: request)
        if request.settings.useProxy, !request.settings.proxyURL.isEmpty {
            arguments += ["--proxy", request.settings.proxyURL]
        } else if adapter.siteID == .youtube {
            // Prevent shell or system proxy variables from silently changing YouTube behavior.
            arguments += ["--proxy", ""]
        }
        if adapter.siteID == .pornhub,
           !request.settings.username.isEmpty,
           !request.credentials.password.isEmpty {
            arguments += ["--username", request.settings.username]
            arguments += ["--password", request.credentials.password]
        }
        if let cookieURL = request.credentials.cookiesFileURL(for: adapter.siteID) {
            arguments += ["--cookies", cookieURL.path]
        }
        return arguments
    }
}
