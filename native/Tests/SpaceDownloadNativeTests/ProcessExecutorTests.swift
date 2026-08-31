import Foundation
import XCTest
@testable import SpaceDownloadNative

final class ProcessExecutorTests: XCTestCase {
    func testStreamsAndCollectsProcessOutput() async {
        let executor = ProcessExecutor()
        let result = await executor.run(
            executable: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["first\\nsecond\\n"],
            onLine: { _ in }
        )

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.lines, ["first", "second"])
    }

    func testLocatesInstalledYtDlp() {
        XCTAssertNotNil(YtDlpLocator.locate())
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
