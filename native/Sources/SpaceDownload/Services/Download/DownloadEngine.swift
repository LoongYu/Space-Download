import Foundation

final class DownloadEngine {
    private let executor: ProcessExecuting
    private let translator: TitleTranslating
    private let thumbnailService: ThumbnailDownloading
    private let metadataLogger: MetadataDebugLogging
    private let tools: ToolLocations
    private let cancellationLock = NSLock()
    private var cancelled = false

    init(
        tools: ToolLocations,
        executor: ProcessExecuting = ProcessExecutor(),
        translator: TitleTranslating = GoogleTitleTranslator(),
        thumbnailService: ThumbnailDownloading = ThumbnailService(),
        metadataLogger: MetadataDebugLogging = MetadataDebugLogger()
    ) {
        self.tools = tools
        self.executor = executor
        self.translator = translator
        self.thumbnailService = thumbnailService
        self.metadataLogger = metadataLogger
    }

    func cancel() {
        cancellationLock.lock()
        cancelled = true
        cancellationLock.unlock()
        executor.cancel()
    }

    func prepareForExecution() {
        cancellationLock.withLock { cancelled = false }
    }

    func execute(
        request: DownloadRequest,
        onEvent: @escaping (DownloadEngineEvent) -> Void
    ) async -> DownloadSummary {
        let builder = YtDlpCommandBuilder(tools: tools)
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceDownload-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let effectiveRequest = requestWithAutomaticPornhubCookies(
            request,
            temporaryDirectory: temporaryDirectory,
            onEvent: onEvent
        )
        var summary = DownloadSummary()
        var preparationFailures: [DownloadFailure] = []
        var items: [DownloadItem] = []

        onEvent(.log("yt-dlp: \(tools.ytDlp.path)"))
        if let ffmpeg = tools.ffmpeg {
            onEvent(.log("ffmpeg: \(ffmpeg.path)"))
        } else {
            onEvent(.log("WARN: 未找到 ffmpeg，合并或格式转换可能失败"))
        }
        if request.sourceURLs.contains(where: { SiteRegistry.adapter(for: $0).siteID == .youtube }) {
            if let runtime = YouTubeJavaScriptRuntimeLocator.locate() {
                onEvent(.log("YouTube JavaScript 运行时：\(runtime.url.path)"))
            } else {
                onEvent(.log("WARN: 未找到 YouTube JavaScript 运行时，部分清晰度可能不可用；建议安装 Deno 或 Node.js"))
            }
        }

        for sourceURL in request.sourceURLs where !isCancelled {
            let adapter = SiteRegistry.adapter(for: sourceURL)
            if adapter.expandsMediaResources {
                onEvent(.log("解析多资源帖子：\(sourceURL.absoluteString)"))
                let extraction = await executor.run(
                    executable: tools.ytDlp,
                    arguments: builder.resourceDiscoveryArguments(for: sourceURL, request: effectiveRequest),
                    onLine: { line in
                        if let message = liveToolMessage(line, phase: "资源解析") { onEvent(.log(message)) }
                    }
                )
                guard extraction.exitCode == 0, let metadata = jsonObject(from: extraction.lines) else {
                    preparationFailures.append(DownloadFailure(
                        title: "\(adapter.displayName) 帖子",
                        url: sourceURL,
                        reason: failureReason(from: extraction)
                    ))
                    continue
                }
                let resources = adapter.mediaResources(from: metadata, sourceURL: sourceURL)
                if resources.isEmpty {
                    preparationFailures.append(DownloadFailure(
                        title: "\(adapter.displayName) 帖子",
                        url: sourceURL,
                        reason: "帖子中未识别到可处理的媒体资源"
                    ))
                    continue
                }
                for resource in resources {
                    guard resource.isDownloadSupported else {
                        preparationFailures.append(DownloadFailure(
                            title: "\(adapter.displayName) 图片资源 \(resource.stableID)",
                            url: sourceURL,
                            reason: "当前版本尚未验证 \(adapter.displayName) 图片下载，因此未宣称或执行图片支持"
                        ))
                        continue
                    }
                    let resourceMetadata = jsonObject(from: resource.metadataJSON) ?? [:]
                    let title = resourceMetadata["title"] as? String ?? ""
                    items.append(DownloadItem(
                        url: sourceURL,
                        title: title,
                        page: nil,
                        pageIndex: resource.selector,
                        resource: resource
                    ))
                }
                onEvent(.log("\(adapter.displayName) 帖子识别到 \(resources.count) 个媒体资源"))
            } else if adapter.classify(sourceURL).isCollection {
                let collectionSources = adapter.collectionSources(for: sourceURL, request: effectiveRequest)
                if adapter.siteID == .pornhub, let pages = request.selectedPages {
                    onEvent(.log("按网页分页解析：\(pages.map(String.init).joined(separator: ", "))"))
                }
                if adapter.siteID == .youtube,
                   adapter.classify(sourceURL) == .playlist,
                   let items = request.youtubePlaylistItems {
                    onEvent(.log("按播放列表序号解析：\(items.map(String.init).joined(separator: ", "))"))
                }

                for source in collectionSources where !isCancelled {
                    onEvent(.log("扫描\(source.label)：\(source.url.absoluteString)"))
                    let extraction = await executor.run(
                        executable: tools.ytDlp,
                        arguments: builder.collectionArguments(for: source.url, request: effectiveRequest),
                        onLine: { line in
                            if let message = liveToolMessage(line, phase: "列表解析") {
                                onEvent(.log(message))
                            }
                        }
                    )
                    guard extraction.exitCode == 0,
                          let object = jsonObject(from: extraction.lines)
                    else {
                        preparationFailures.append(DownloadFailure(
                            title: source.label,
                            url: source.url,
                            reason: failureReason(from: extraction)
                        ))
                        continue
                    }
                    let entries = object["entries"] as? [[String: Any]] ?? []
                    var pageIndex = 0
                    for entry in entries {
                        guard let url = adapter.resolvedEntryURL(from: entry) else { continue }
                        pageIndex += 1
                        items.append(DownloadItem(
                            url: url,
                            title: entry["title"] as? String ?? "",
                            page: source.page,
                            pageIndex: pageIndex
                        ))
                    }
                    onEvent(.log("\(source.label)识别到 \(pageIndex) 个视频"))
                    if pageIndex == 0 {
                        preparationFailures.append(DownloadFailure(
                            title: source.label,
                            url: source.url,
                            reason: "未获取到可下载的视频链接"
                        ))
                    }
                }
            } else {
                items.append(DownloadItem(url: sourceURL, title: "", page: nil, pageIndex: nil))
            }
        }

        items = deduplicated(items) { duplicate in
            if let id = duplicate.resource?.stableID {
                onEvent(.log("重复媒体 ID \(id)，已跳过并继续后续任务"))
            } else {
                onEvent(.log("重复链接 \(duplicate.url.absoluteString)，已跳过并继续后续任务"))
            }
        }
        onEvent(.prepared(total: items.count + preparationFailures.count))
        for failure in preparationFailures {
            summary.failures.append(failure)
            onEvent(.itemFailed(failure))
        }

        for (offset, originalItem) in items.enumerated() {
            if isCancelled { break }
            var item = originalItem
            let itemAdapter = SiteRegistry.adapter(for: item.url)
            let mediaSettings = effectiveRequest.settings.mediaSettings(for: itemAdapter.siteID)
            onEvent(.itemStarted(
                index: summary.completed + summary.failures.count + 1,
                total: items.count + preparationFailures.count,
                title: item.title,
                url: item.url
            ))

            let downloadDirectory = URL(fileURLWithPath: effectiveRequest.settings.downloadPath, isDirectory: true)
            if let inferredID = item.resource?.stableID ?? ExistingVideoLocator.videoID(from: item.url),
               let existingFile = ExistingVideoLocator.find(videoID: inferredID, in: downloadDirectory) {
                summary.completed += 1
                onEvent(.itemSkipped(
                    title: existingFile.deletingPathExtension().lastPathComponent,
                    url: item.url,
                    existingFile: existingFile
                ))
                continue
            }

            let metadataExecution: ProcessExecutionResult?
            let metadata: [String: Any]?
            if let data = item.resource?.metadataJSON {
                metadataExecution = nil
                metadata = jsonObject(from: data)
            } else {
                let execution = await executor.run(
                    executable: tools.ytDlp,
                    arguments: builder.metadataArguments(for: item.url, request: effectiveRequest),
                    onLine: { line in
                        if let message = liveToolMessage(line, phase: "视频解析") { onEvent(.log(message)) }
                    }
                )
                metadataExecution = execution
                metadata = execution.exitCode == 0 ? jsonObject(from: execution.lines) : nil
            }
            guard let metadata else {
                if isCancelled { break }
                let failure = DownloadFailure(
                    title: item.title.isEmpty ? "未知标题" : item.title,
                    url: item.url,
                    reason: metadataExecution.map(failureReason(from:)) ?? "资源 metadata 无效"
                )
                summary.failures.append(failure)
                onEvent(.itemFailed(failure))
                continue
            }

            if let title = metadata["title"] as? String, !title.isEmpty {
                item = DownloadItem(
                    url: item.url,
                    title: title,
                    page: item.page,
                    pageIndex: item.pageIndex,
                    resource: item.resource
                )
            }
            if let metadataID = metadata["id"] as? String,
               let existingFile = ExistingVideoLocator.find(videoID: metadataID, in: downloadDirectory) {
                summary.completed += 1
                onEvent(.itemSkipped(title: item.title, url: item.url, existingFile: existingFile))
                continue
            }
            let metadataLabel = metadataLabel(item: item, position: offset + 1)
            onEvent(.log(metadataSummaryLog(metadata, label: metadataLabel)))
            do {
                let logURL = try metadataLogger.write(metadata: metadata, label: metadataLabel)
                if logURL.path != "/dev/null" {
                    onEvent(.log("完整 metadata 已保存：\(logURL.path)"))
                }
            } catch {
                onEvent(.log("WARN: 完整 metadata 保存失败：\(error.localizedDescription)"))
            }

            let translatedTitle = mediaSettings.translateTitle
                ? await translator.translate(item.title)
                : item.title
            if translatedTitle != item.title {
                onEvent(.log("标题翻译：\(item.title) -> \(translatedTitle)"))
            }

            var resultInfo: [String: String] = [:]
            let downloadExecution = await executor.run(
                executable: tools.ytDlp,
                arguments: builder.downloadArguments(
                    for: item,
                    request: effectiveRequest,
                    temporaryDirectory: temporaryDirectory,
                    translatedTitle: translatedTitle
                ),
                onLine: { line in
                    guard let parsed = YtDlpOutputParser.parse(line) else { return }
                    switch parsed {
                    case let .progress(progress):
                        onEvent(.itemProgress(progress.fraction, speed: progress.speed, eta: progress.eta))
                    case let .result(result):
                        resultInfo = result
                        if let path = result["filepath"] ?? result["_filename"] {
                            onEvent(.log("[下载] 文件已写入：\(path)"))
                        }
                    case let .log(message):
                        onEvent(.log("[下载] \(message)"))
                    }
                }
            )

            if isCancelled { break }
            guard downloadExecution.exitCode == 0 else {
                let failure = DownloadFailure(
                    title: item.title.isEmpty ? "未知标题" : item.title,
                    url: item.url,
                    reason: failureReason(from: downloadExecution)
                )
                summary.failures.append(failure)
                onEvent(.itemFailed(failure))
                continue
            }

            summary.completed += 1
            onEvent(.itemSucceeded(title: item.title, url: item.url))
            if mediaSettings.embedThumbnail,
               let thumbnail = itemAdapter.preferredThumbnail(from: metadata),
               let videoPath = resultInfo["filepath"] ?? resultInfo["_filename"] {
                do {
                    if let width = thumbnail.width, let height = thumbnail.height {
                        onEvent(.log("封面选择：\(width)×\(height)"))
                    }
                    let thumbnailPath = try await thumbnailService.download(
                        from: thumbnail.url,
                        beside: URL(fileURLWithPath: videoPath),
                        headers: thumbnail.headers
                    )
                    onEvent(.log("已保存封面图：\(thumbnailPath.lastPathComponent)"))
                } catch {
                    onEvent(.log("WARN: 封面图保存失败：\(error.localizedDescription)"))
                }
            }
        }

        summary.wasCancelled = isCancelled
        return summary
    }

    private var isCancelled: Bool {
        cancellationLock.withLock { cancelled }
    }

    private func requestWithAutomaticPornhubCookies(
        _ request: DownloadRequest,
        temporaryDirectory: URL,
        onEvent: (DownloadEngineEvent) -> Void
    ) -> DownloadRequest {
        guard request.credentials.cookiesFileURL == nil,
              request.sourceURLs.contains(where: CollectionURLBuilder.isPornhub)
        else {
            return request
        }
        let cookieURL = temporaryDirectory.appendingPathComponent("pornhub-cookies.txt")
        let cookieText = """
        # Netscape HTTP Cookie File
        .pornhub.com\tTRUE\t/\tFALSE\t0\tage_verified\t1
        .pornhub.com\tTRUE\t/\tFALSE\t0\taccessAgeDisclaimerPH\t1
        .pornhub.com\tTRUE\t/\tFALSE\t0\taccessPH\t1
        .pornhub.com\tTRUE\t/\tFALSE\t0\taccessAgeDisclaimerUK\t1
        """
        do {
            try cookieText.write(to: cookieURL, atomically: true, encoding: .utf8)
            onEvent(.log("已启用 Pornhub 年龄验证 Cookies"))
            return DownloadRequest(
                sourceURLs: request.sourceURLs,
                settings: request.settings,
                credentials: DownloadCredentials(
                    password: request.credentials.password,
                    cookiesFileURL: cookieURL,
                    youtubeCookiesFileURL: request.credentials.youtubeCookiesFileURL,
                    xCookiesFileURL: request.credentials.xCookiesFileURL,
                    tiktokCookiesFileURL: request.credentials.tiktokCookiesFileURL,
                    douyinCookiesFileURL: request.credentials.douyinCookiesFileURL,
                    instagramCookiesFileURL: request.credentials.instagramCookiesFileURL
                ),
                selectedPages: request.selectedPages,
                youtubePlaylistItems: request.youtubePlaylistItems
            )
        } catch {
            onEvent(.log("WARN: 无法创建 Pornhub 临时 Cookies：\(error.localizedDescription)"))
            return request
        }
    }
}

private func jsonObject(from lines: [String]) -> [String: Any]? {
    for line in lines.reversed() {
        guard let start = line.firstIndex(of: "{") else { continue }
        let candidate = String(line[start...])
        guard let data = candidate.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { continue }
        return object
    }
    return nil
}

private func jsonObject(from data: Data) -> [String: Any]? {
    try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

private func failureReason(from execution: ProcessExecutionResult) -> String {
    let meaningful = execution.lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    let combined = meaningful.joined(separator: "\n")
    if combined.localizedCaseInsensitiveContains("Sign in to confirm you’re not a bot")
        || combined.localizedCaseInsensitiveContains("Sign in to confirm you're not a bot") {
        return "YouTube 拒绝了当前网络的匿名访问。请更换可用代理后重试；如视频确实需要登录，只能在 YouTube 站点设置中手动选择 cookies.txt，应用不会读取浏览器数据。"
    }
    return meaningful.suffix(5).joined(separator: " | ").nilIfEmpty
        ?? "yt-dlp 退出码 \(execution.exitCode)"
}

private func metadataLabel(item: DownloadItem, position: Int) -> String {
    if let page = item.page, let pageIndex = item.pageIndex {
        return "第 \(page) 页 / 第 \(pageIndex) 个视频"
    }
    return "第 \(position) 个视频"
}

private func metadataSummaryLog(_ metadata: [String: Any], label: String) -> String {
    let title = metadata["title"] as? String ?? "未知标题"
    let id = metadata["id"] as? String ?? "--"
    let uploader = metadata["uploader"] as? String ?? metadata["channel"] as? String ?? "--"
    let duration = metadata["duration_string"] as? String
        ?? (metadata["duration"] as? NSNumber).map { "\($0.intValue) 秒" }
        ?? "--"
    let resolution = metadata["resolution"] as? String
        ?? (metadata["height"] as? NSNumber).map { "\($0.intValue)p" }
        ?? "--"
    let format = metadata["format_id"] as? String ?? metadata["ext"] as? String ?? "--"
    let source = metadata["webpage_url"] as? String ?? metadata["original_url"] as? String ?? "--"
    return "视频信息 [\(label)]：标题 \(title) | ID \(id) | 作者 \(uploader) | 时长 \(duration) | 清晰度 \(resolution) | 格式 \(format)\n来源：\(source)"
}

private func liveToolMessage(_ line: String, phase: String) -> String? {
    let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }
    if value.first == "{", value.last == "}" { return nil }
    return "[\(phase)] \(value)"
}

private func deduplicated(_ items: [DownloadItem], onDuplicate: (DownloadItem) -> Void) -> [DownloadItem] {
    var seen = Set<String>()
    return items.filter {
        let key = $0.resource.map { "resource:\($0.stableID)" } ?? "url:\($0.url.absoluteString)"
        let inserted = seen.insert(key).inserted
        if !inserted { onDuplicate($0) }
        return inserted
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
