import XCTest
@testable import SpaceDownloadNative

final class YtDlpOutputParserTests: XCTestCase {
    func testParsesProgressLine() {
        let parsed = YtDlpOutputParser.parse("SPACEDOWNLOAD_PROGRESS: 42.5%| 3.2MiB/s| 00:12")
        XCTAssertEqual(parsed, .progress(ParsedProgress(fraction: 0.425, speed: "3.2MiB/s", eta: "00:12")))
    }

    func testParsesResultJSON() {
        let parsed = YtDlpOutputParser.parse(#"SPACEDOWNLOAD_RESULT:{"id":"abc","title":"Title","filepath":"/tmp/a.mp4"}"#)
        XCTAssertEqual(parsed, .result(["id": "abc", "title": "Title", "filepath": "/tmp/a.mp4"]))
    }
}
