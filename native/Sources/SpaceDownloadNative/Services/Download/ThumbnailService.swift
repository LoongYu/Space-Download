import Foundation

protocol ThumbnailDownloading {
    func download(from sourceURL: URL, beside videoURL: URL) async throws -> URL
}

struct ThumbnailService: ThumbnailDownloading {
    func download(from sourceURL: URL, beside videoURL: URL) async throws -> URL {
        var request = URLRequest(url: sourceURL)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              !data.isEmpty
        else {
            throw URLError(.badServerResponse)
        }
        let destination = videoURL.deletingPathExtension().appendingPathExtension("jpg")
        try data.write(to: destination, options: .atomic)
        return destination
    }
}
