import Foundation

protocol ThumbnailDownloading {
    func download(
        from sourceURL: URL,
        beside videoURL: URL,
        headers: [String: String]
    ) async throws -> URL
}

struct ThumbnailService: ThumbnailDownloading {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func download(
        from sourceURL: URL,
        beside videoURL: URL,
        headers: [String: String]
    ) async throws -> URL {
        var request = URLRequest(url: sourceURL)
        request.timeoutInterval = 20
        request.setValue(Self.defaultUserAgent, forHTTPHeaderField: "User-Agent")
        for (field, value) in headers where !value.isEmpty {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ThumbnailDownloadError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ThumbnailDownloadError.httpStatus(
                httpResponse.statusCode,
                host: sourceURL.host ?? sourceURL.absoluteString
            )
        }
        guard !data.isEmpty else {
            throw ThumbnailDownloadError.emptyResponse
        }
        guard httpResponse.mimeType?.lowercased().hasPrefix("image/") == true else {
            throw ThumbnailDownloadError.invalidContentType(
                httpResponse.value(forHTTPHeaderField: "Content-Type")
            )
        }

        let destination = videoURL.deletingPathExtension()
            .appendingPathExtension(Self.fileExtension(for: httpResponse.mimeType))
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private static let defaultUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120 Safari/537.36"

    private static func fileExtension(for mimeType: String?) -> String {
        switch mimeType?.lowercased() {
        case "image/png": "png"
        case "image/webp": "webp"
        default: "jpg"
        }
    }
}

enum ThumbnailDownloadError: LocalizedError, Equatable {
    case invalidResponse
    case httpStatus(Int, host: String)
    case emptyResponse
    case invalidContentType(String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "封面服务器返回了无效响应"
        case let .httpStatus(statusCode, host):
            "封面服务器 HTTP \(statusCode)（\(host)）"
        case .emptyResponse:
            "封面服务器返回了空文件"
        case let .invalidContentType(contentType):
            "封面响应不是图片（\(contentType ?? "未知类型")）"
        }
    }
}
