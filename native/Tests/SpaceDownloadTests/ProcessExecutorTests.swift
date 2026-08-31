import Foundation
import XCTest
@testable import SpaceDownload

final class ProcessExecutorTests: XCTestCase {
    func testStreamsAndCollectsProcessOutput() async {
        for _ in 0..<25 {
            let executor = ProcessExecutor()
            let result = await executor.run(
                executable: URL(fileURLWithPath: "/usr/bin/printf"),
                arguments: ["first\\nsecond\\n"],
                onLine: { _ in }
            )

            XCTAssertEqual(result.exitCode, 0)
            XCTAssertEqual(result.lines, ["first", "second"])
        }
    }

    func testLocatesToolsFromPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let ytDlp = directory.appendingPathComponent("yt-dlp")
        let ffmpeg = directory.appendingPathComponent("ffmpeg")
        for executable in [ytDlp, ffmpeg] {
            try Data("#!/bin/sh\n".utf8).write(to: executable)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: executable.path
            )
        }

        let locations = YtDlpLocator.locate(
            bundle: Bundle(for: Self.self),
            environment: ["PATH": directory.path],
            systemDirectories: []
        )

        XCTAssertEqual(locations, ToolLocations(ytDlp: ytDlp, ffmpeg: ffmpeg))
    }

    func testCancelTerminatesRunningProcess() async throws {
        let executor = ProcessExecutor()
        let task = Task {
            await executor.run(
                executable: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["5"],
                onLine: { _ in }
            )
        }
        try await Task.sleep(for: .milliseconds(100))
        executor.cancel()
        let result = await task.value

        XCTAssertNotEqual(result.exitCode, 0)
    }
}
