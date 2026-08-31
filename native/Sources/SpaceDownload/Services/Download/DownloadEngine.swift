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

        for sourceURL in request.sourceURLs where !isCancelled {
            if CollectionURLBuilder.isCollection(sourceURL) {
                let collectionURLs: [(URL, Int?)]
                if let pages = request.selectedPages,
                   CollectionURLBuilder.supportsPageSelection(sourceURL) {
                    collectionURLs = pages.compactMap { page in
                        CollectionURLBuilder.pageURL(from: sourceURL, page: page).map { ($0, page) }
                    }
                    onEvent(.log("按网页分页解析：\(pages.map(String.init).joined(separator: ", "))"))
                } else {
                    if request.selectedPages != nil {
                        onEvent(.log("WARN: 当前列表不支持网页分页，按整个列表下载"))
                    }
                    collectionURLs = [(sourceURL, nil)]
                }

                for (collectionURL, page) in collectionURLs where !isCancelled {
                    onEvent(.log("扫描列表：\(collectionURL.absoluteString)"))
                    let extraction = await executor.run(
                        executable: tools.ytDlp,
                        arguments: builder.collectionArguments(for: collectionURL, request: effectiveRequest),
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
                            title: page.map { "第 \($0) 页" } ?? "批量列表",
                            url: collectionURL,
                            reason: failureReason(from: extraction)
                        ))
                        continue
                    }
                    let entries = object["entries"] as? [[String: Any]] ?? []
                    var pageIndex = 0
                    for entry in entries {
                        guard let url = resolvedURL(from: entry) else { continue }
                        pageIndex += 1
                        items.append(DownloadItem(
                            url: url,
                            title: entry["title"] as? String ?? "",
                            page: page,
                            pageIndex: pageIndex
                        ))
                    }
                    onEvent(.log("\(page.map { "第 \($0) 页" } ?? "列表")识别到 \(pageIndex) 个视频"))
                    if pageIndex == 0 {
                        preparationFailures.append(DownloadFailure(
                            title: page.map { "第 \($0) 页" } ?? "批量列表",
                            url: collectionURL,
                            reason: "未获取到可下载的视频链接"
                        ))
                    }
                }
            } else {
                items.append(DownloadItem(url: sourceURL, title: "", page: nil, pageIndex: nil))
            }
        }

        items = deduplicated(items)
        onEvent(.prepared(total: items.count + preparationFailures.count))
        for failure in preparationFailures {
            summary.failures.append(failure)
            onEvent(.itemFailed(failure))
        }

        for (offset, originalItem) in items.enumerated() {
            if isCancelled { break }
            var item = originalItem
            onEvent(.itemStarted(
                index: summary.completed + summary.failures.count + 1,
                total: items.count + preparationFailures.count,
                title: item.title,
                url: item.url
            ))

            let downloadDirectory = URL(fileURLWithPath: effectiveRequest.settings.downloadPath, isDirectory: true)
            if let inferredID = ExistingVideoLocator.videoID(from: item.url),
               let existingFile = ExistingVideoLocator.find(videoID: inferredID, in: downloadDirectory) {
                summary.completed += 1
                onEvent(.itemSkipped(
                    title: existingFile.deletingPathExtension().lastPathComponent,
                    url: item.url,
                    existingFile: existingFile
                ))
                continue
            }

            let metadataExecution = await executor.run(
                executable: tools.ytDlp,
                arguments: builder.metadataArguments(for: item.url, request: effectiveRequest),
                onLine: { line in
                    if let message = liveToolMessage(line, phase: "视频解析") {
                        onEvent(.log(message))
                    }
                }
            )
            guard metadataExecution.exitCode == 0,
                  let metadata = jsonObject(from: metadataExecution.lines)
            else {
                if isCancelled { break }
                let failure = DownloadFailure(
                    title: item.title.isEmpty ? "未知标题" : item.title,
                    url: item.url,
                    reason: failureReason(from: metadataExecution)
                )
                summary.failures.append(failure)
                onEvent(.itemFailed(failure))
                continue
            }

            if let title = metadata["title"] as? String, !title.isEmpty {
                item = DownloadItem(url: item.url, title: title, page: item.page, pageIndex: item.pageIndex)
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

            let translatedTitle = effectiveRequest.settings.translateTitle
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
            if effectiveRequest.settings.embedThumbnail,
               let thumbnailText = metadata["thumbnail"] as? String,
               let thumbnailURL = URL(string: thumbnailText),
               let videoPath = resultInfo["filepath"] ?? resultInfo["_filename"] {
                do {
                    let thumbnailPath = try await thumbnailService.download(
                        from: thumbnailURL,
                        beside: URL(fileURLWithPath: videoPath),
                        headers: metadataHTTPHeaders(metadata)
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
                credentials: DownloadCredentials(password: request.credentials.password, cookiesFileURL: cookieURL),
                selectedPages: request.selectedPages
            )
        } catch {
            onEvent(.log("WARN: 无法创建 Pornhub 临时 Cookies：\(error.localizedDescription)"))
            return request
        }
    }
}

private func metadataHTTPHeaders(_ metadata: [String: Any]) -> [String: String] {
    guard let values = metadata["http_headers"] as? [String: Any] else { return [:] }
    return values.reduce(into: [:]) { result, entry in
        if let value = entry.value as? String {
            result[entry.key] = value
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

private func resolvedURL(from entry: [String: Any]) -> URL? {
    for key in ["webpage_url", "original_url", "url"] {
        if let value = entry[key] as? String,
           let url = URL(string: value),
           ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            return url
        }
    }
    return nil
}

private func failureReason(from execution: ProcessExecutionResult) -> String {
    let meaningful = execution.lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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

private func deduplicated(_ items: [DownloadItem]) -> [DownloadItem] {
    var seen = Set<URL>()
    return items.filter { seen.insert($0.url).inserted }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
