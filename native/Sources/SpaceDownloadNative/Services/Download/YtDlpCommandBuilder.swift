import Foundation

struct YtDlpCommandBuilder {
    static let progressPrefix = "SPACEDOWNLOAD_PROGRESS:"
    static let resultPrefix = "SPACEDOWNLOAD_RESULT:"

    let tools: ToolLocations

    func metadataArguments(for url: URL, request: DownloadRequest) -> [String] {
        commonNetworkArguments(for: url, request: request) + [
            "--no-playlist",
            "--skip-download",
            "--dump-single-json",
            url.absoluteString,
        ]
    }

    func collectionArguments(for url: URL, request: DownloadRequest) -> [String] {
        commonNetworkArguments(for: url, request: request) + [
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
        var arguments = commonNetworkArguments(for: item.url, request: request)
        arguments += [
            "--no-playlist",
            "--newline",
            "--no-color",
            "--retries", "5",
            "--fragment-retries", "5",
            "--concurrent-fragments", "8",
            "--socket-timeout", "30",
            "--no-part",
            "--format", settings.quality.ytDlpFormat,
            "--merge-output-format", settings.outputFormat.rawValue,
            "--recode-video", settings.outputFormat.rawValue,
            "--paths", "home:\(settings.downloadPath)",
            "--paths", "temp:\(temporaryDirectory.path)",
            "--output", "\(settings.resolvedFilenameTemplate).%(ext)s",
            "--progress-template", "download:\(Self.progressPrefix)%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print", "after_move:\(Self.resultPrefix)%()j",
        ]
        if let ffmpeg = tools.ffmpeg {
            arguments += ["--ffmpeg-location", ffmpeg.path]
        }
        if let translatedTitle, !translatedTitle.isEmpty, translatedTitle != item.title {
            arguments += ["--replace-in-metadata", "title", "^.*$", translatedTitle]
        }
        arguments.append(item.url.absoluteString)
        return arguments
    }

    private func commonNetworkArguments(for url: URL, request: DownloadRequest) -> [String] {
        var arguments = [
            "--no-warnings",
            "--user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120 Safari/537.36",
            "--add-header", "Accept-Language:en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7",
        ]
        if CollectionURLBuilder.isPornhub(url) {
            arguments += ["--referer", "https://www.pornhub.com/"]
        }
        if request.settings.useProxy, !request.settings.proxyURL.isEmpty {
            arguments += ["--proxy", request.settings.proxyURL]
        }
        if !request.settings.username.isEmpty, !request.credentials.password.isEmpty {
            arguments += ["--username", request.settings.username]
            arguments += ["--password", request.credentials.password]
        }
        if let cookieURL = request.credentials.cookiesFileURL {
            arguments += ["--cookies", cookieURL.path]
        }
        return arguments
    }
}
