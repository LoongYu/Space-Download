import Foundation

protocol TitleTranslating {
    func translate(_ text: String) async -> String
}

struct GoogleTitleTranslator: TitleTranslating {
    func translate(_ text: String) async -> String {
        guard !text.isEmpty else { return text }
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")
        components?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: "zh-CN"),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text),
        ]
        guard let url = components?.url else { return text }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let segments = payload.first as? [Any]
        else {
            return text
        }
        let translated = segments.compactMap { segment -> String? in
            guard let values = segment as? [Any], let value = values.first as? String else { return nil }
            return value
        }.joined()
        return translated.isEmpty ? text : translated
    }
}

struct IdentityTitleTranslator: TitleTranslating {
    func translate(_ text: String) async -> String { text }
}
