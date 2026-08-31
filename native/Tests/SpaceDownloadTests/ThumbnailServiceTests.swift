import Foundation
import XCTest
@testable import SpaceDownload

final class ThumbnailServiceTests: XCTestCase {
    override func tearDown() {
        ThumbnailURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testUsesMetadataHeadersAndWritesJPEG() async throws {
        let sourceURL = try XCTUnwrap(URL(string: "https://pix.example.com/thumbnail"))
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceDownload-\(UUID().uuidString).mp4")
        let expectedData = Data([0xff, 0xd8, 0xff, 0xd9])
        ThumbnailURLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://www.pornhub.com/")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://www.pornhub.com")
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "metadata-agent")
            return (
                HTTPURLResponse(
                    url: sourceURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "image/jpeg"]
                )!,
                expectedData
            )
        }
        let service = ThumbnailService(session: makeSession())

        let outputURL = try await service.download(
            from: sourceURL,
            beside: videoURL,
            headers: [
                "Referer": "https://www.pornhub.com/",
                "Origin": "https://www.pornhub.com",
                "User-Agent": "metadata-agent",
            ]
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        XCTAssertEqual(outputURL.pathExtension, "jpg")
        XCTAssertEqual(try Data(contentsOf: outputURL), expectedData)
    }

    func testReportsHTTPStatusAndHost() async throws {
        let sourceURL = try XCTUnwrap(URL(string: "https://pix.example.com/thumbnail"))
        ThumbnailURLProtocolStub.handler = { _ in
            (
                HTTPURLResponse(
                    url: sourceURL,
                    statusCode: 403,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/html"]
                )!,
                Data("forbidden".utf8)
            )
        }
        let service = ThumbnailService(session: makeSession())

        do {
            _ = try await service.download(
                from: sourceURL,
                beside: URL(fileURLWithPath: "/tmp/video.mp4"),
                headers: [:]
            )
            XCTFail("Expected HTTP status failure")
        } catch let error as ThumbnailDownloadError {
            XCTAssertEqual(error, .httpStatus(403, host: "pix.example.com"))
            XCTAssertEqual(error.localizedDescription, "封面服务器 HTTP 403（pix.example.com）")
        }
    }

    func testLiveSignedThumbnailWhenConfigured() async throws {
        guard let urlText = ProcessInfo.processInfo.environment["SPACEDOWNLOAD_LIVE_THUMBNAIL_URL"],
              let sourceURL = URL(string: urlText)
        else {
            throw XCTSkip("Set SPACEDOWNLOAD_LIVE_THUMBNAIL_URL to run")
        }
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceDownload-Live-Thumbnail-\(UUID().uuidString).mp4")

        let outputURL = try await ThumbnailService().download(
            from: sourceURL,
            beside: videoURL,
            headers: [
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Origin": "https://www.pornhub.com",
                "Referer": "https://www.pornhub.com/",
            ]
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        XCTAssertGreaterThan(try Data(contentsOf: outputURL).count, 1_000)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ThumbnailURLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

private final class ThumbnailURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
