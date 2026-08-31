import Foundation

struct LinkParseResult: Equatable {
    let validURLs: [URL]
    let invalidEntries: [String]
}

enum LinkParser {
    static func parse(_ text: String) -> LinkParseResult {
        var urls: [URL] = []
        var invalidEntries: [String] = []
        var seen = Set<String>()

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard let url = URL(string: line),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  url.host != nil
            else {
                invalidEntries.append(line)
                continue
            }
            if seen.insert(url.absoluteString).inserted {
                urls.append(url)
            }
        }

        return LinkParseResult(validURLs: urls, invalidEntries: invalidEntries)
    }
}
