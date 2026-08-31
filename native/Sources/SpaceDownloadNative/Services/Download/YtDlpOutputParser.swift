import Foundation

struct ParsedProgress: Equatable {
    let fraction: Double
    let speed: String
    let eta: String
}

enum ParsedYtDlpLine: Equatable {
    case progress(ParsedProgress)
    case result([String: String])
    case log(String)
}

enum YtDlpOutputParser {
    static func parse(_ line: String) -> ParsedYtDlpLine? {
        let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix(YtDlpCommandBuilder.progressPrefix) {
            let payload = String(value.dropFirst(YtDlpCommandBuilder.progressPrefix.count))
            let fields = payload.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 3 else { return .log(value) }
            let percentText = fields[0]
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespaces)
            let fraction = min(max((Double(percentText) ?? 0) / 100, 0), 1)
            return .progress(ParsedProgress(fraction: fraction, speed: fields[1].trimmed, eta: fields[2].trimmed))
        }

        if value.hasPrefix(YtDlpCommandBuilder.resultPrefix) {
            let payload = String(value.dropFirst(YtDlpCommandBuilder.resultPrefix.count))
            guard let data = payload.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return .log(value)
            }
            var result: [String: String] = [:]
            for key in ["id", "title", "webpage_url", "filepath", "_filename", "thumbnail"] {
                if let string = object[key] as? String { result[key] = string }
            }
            return .result(result)
        }

        return .log(value)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
