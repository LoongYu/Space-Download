import Darwin
import Foundation

struct ProcessExecutionResult: Equatable {
    let exitCode: Int32
    let lines: [String]
}

protocol ProcessExecuting: AnyObject {
    func run(executable: URL, arguments: [String], onLine: @escaping (String) -> Void) async -> ProcessExecutionResult
    func cancel()
}

final class ProcessExecutor: ProcessExecuting {
    private let lock = NSLock()
    private var currentProcess: Process?

    func run(executable: URL, arguments: [String], onLine: @escaping (String) -> Void) async -> ProcessExecutionResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            let output = ProcessOutputAccumulator(onLine: onLine)

            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            process.environment = ProcessInfo.processInfo.environment.merging([
                "PYTHONUNBUFFERED": "1",
                "NO_COLOR": "1",
            ]) { _, new in new }

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                output.consume(String(decoding: data, as: UTF8.self))
            }

            process.terminationHandler = { [weak self] terminatedProcess in
                pipe.fileHandleForReading.readabilityHandler = nil
                let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
                if !remaining.isEmpty {
                    output.consume(String(decoding: remaining, as: UTF8.self))
                }
                output.flush()
                self?.lock.lock()
                if self?.currentProcess === terminatedProcess {
                    self?.currentProcess = nil
                }
                self?.lock.unlock()
                continuation.resume(returning: ProcessExecutionResult(
                    exitCode: terminatedProcess.terminationStatus,
                    lines: output.snapshot()
                ))
            }

            do {
                lock.lock()
                currentProcess = process
                lock.unlock()
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                lock.lock()
                currentProcess = nil
                lock.unlock()
                continuation.resume(returning: ProcessExecutionResult(
                    exitCode: -1,
                    lines: [error.localizedDescription]
                ))
            }
        }
    }

    func cancel() {
        lock.lock()
        let process = currentProcess
        lock.unlock()
        guard let process, process.isRunning else { return }
        process.terminate()
        let processIdentifier = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            if process.isRunning {
                kill(processIdentifier, SIGKILL)
            }
        }
    }
}

private final class ProcessOutputAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var bufferedText = ""
    private var lines: [String] = []
    private let onLine: (String) -> Void

    init(onLine: @escaping (String) -> Void) {
        self.onLine = onLine
    }

    func consume(_ text: String) {
        lock.lock()
        bufferedText += text
        var parts = bufferedText.components(separatedBy: .newlines)
        bufferedText = parts.removeLast()
        let completeLines = parts.filter { !$0.isEmpty }
        lines.append(contentsOf: completeLines)
        lock.unlock()
        completeLines.forEach(onLine)
    }

    func flush() {
        lock.lock()
        let trailing = bufferedText
        bufferedText = ""
        if !trailing.isEmpty { lines.append(trailing) }
        lock.unlock()
        if !trailing.isEmpty { onLine(trailing) }
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }
}
