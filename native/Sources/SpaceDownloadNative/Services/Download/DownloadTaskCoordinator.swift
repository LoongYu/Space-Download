import Foundation

enum DownloadTaskStatus: Equatable {
    case idle
    case running
    case stopping
    case completed
    case failed(String)

    var label: String {
        switch self {
        case .idle: return "等待任务"
        case .running: return "正在下载"
        case .stopping: return "正在停止"
        case .completed: return "任务已完成"
        case let .failed(message): return "任务失败：\(message)"
        }
    }

    var isActive: Bool { self == .running || self == .stopping }
}

@MainActor
final class DownloadTaskCoordinator: ObservableObject {
    @Published private(set) var status: DownloadTaskStatus = .idle
    @Published private(set) var progress = 0.0
    @Published private(set) var completedCount = 0
    @Published private(set) var failedCount = 0
    @Published private(set) var currentIndex = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var currentTitle = ""
    @Published private(set) var speed = "--"
    @Published private(set) var eta = "--"
    @Published private(set) var logs = ["SpaceDownload Native 已就绪"]
    @Published private(set) var failures: [DownloadFailure] = []
    @Published private(set) var pendingURLs: [URL] = []

    private var engine: DownloadEngine?
    private var task: Task<Void, Never>?

    init(engine: DownloadEngine? = nil) {
        self.engine = engine
    }

    func start(request: DownloadRequest) {
        guard !request.sourceURLs.isEmpty, !status.isActive else { return }
        if engine == nil, let tools = YtDlpLocator.locate() {
            engine = DownloadEngine(tools: tools)
        }
        guard let engine else {
            status = .failed("未找到 yt-dlp。请安装 yt-dlp，或将可执行文件放入应用 Resources 目录")
            appendLog("ERROR: 未找到 yt-dlp")
            return
        }

        pendingURLs = request.sourceURLs
        progress = 0
        completedCount = 0
        failedCount = 0
        currentIndex = 0
        totalCount = 0
        currentTitle = ""
        speed = "--"
        eta = "--"
        failures = []
        status = .running
        appendLog("已创建任务，共 \(request.sourceURLs.count) 个输入链接")
        engine.prepareForExecution()

        let coordinator = self
        task = Task.detached(priority: .userInitiated) { [coordinator, engine, request] in
            let summary = await engine.execute(request: request) { [coordinator] event in
                DispatchQueue.main.sync {
                    coordinator.handle(event)
                }
            }
            await MainActor.run {
                coordinator.finish(summary)
            }
        }
    }

    func stop() {
        guard status == .running else { return }
        status = .stopping
        appendLog("正在停止当前 yt-dlp 进程")
        engine?.cancel()
    }

    func reset() {
        guard !status.isActive else { return }
        status = .idle
        progress = 0
        completedCount = 0
        failedCount = 0
        currentIndex = 0
        totalCount = 0
        currentTitle = ""
        speed = "--"
        eta = "--"
        failures = []
        pendingURLs = []
    }

    private func handle(_ event: DownloadEngineEvent) {
        switch event {
        case let .log(message):
            appendLog(message)
        case let .prepared(total):
            totalCount = total
            appendLog("已准备下载队列，共 \(total) 个项目")
        case let .itemStarted(index, total, title, url):
            currentIndex = index
            totalCount = total
            currentTitle = title.isEmpty ? url.absoluteString : title
            speed = "--"
            eta = "--"
            appendLog("正在处理 [\(index)/\(total)]：\(currentTitle)")
        case let .itemProgress(itemProgress, itemSpeed, itemETA):
            speed = itemSpeed.isEmpty ? "--" : itemSpeed
            eta = itemETA.isEmpty ? "--" : itemETA
            let total = max(totalCount, 1)
            progress = min((Double(completedCount + failedCount) + itemProgress) / Double(total), 1)
        case let .itemSucceeded(title, url):
            completedCount += 1
            updateOverallProgress()
            appendLog("下载成功：\(title.isEmpty ? url.absoluteString : title)")
        case let .itemFailed(failure):
            failures.append(failure)
            failedCount += 1
            updateOverallProgress()
            appendLog("下载失败：\(failure.title) | \(failure.url.absoluteString) | \(failure.reason)")
        }
    }

    private func finish(_ summary: DownloadSummary) {
        pendingURLs = []
        speed = "--"
        eta = "--"
        if summary.wasCancelled || status == .stopping {
            status = .idle
            appendLog("任务已停止：成功 \(completedCount) 个，失败 \(failedCount) 个")
            return
        }
        if !failures.isEmpty {
            appendLog("失败项目汇总，共 \(failures.count) 个：")
            for (index, failure) in failures.enumerated() {
                appendLog("\(index + 1). \(failure.title) | \(failure.url.absoluteString) | \(failure.reason)")
            }
        }
        progress = totalCount == 0 ? 0 : 1
        status = .completed
        appendLog("任务完成：成功 \(completedCount) 个，失败 \(failedCount) 个")
    }

    private func updateOverallProgress() {
        progress = totalCount == 0 ? 0 : min(Double(completedCount + failedCount) / Double(totalCount), 1)
    }

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        logs.append("[\(formatter.string(from: Date()))] \(message)")
        if logs.count > 2_000 { logs.removeFirst(logs.count - 2_000) }
    }
}
