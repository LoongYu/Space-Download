import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: DownloadSettings {
        didSet { save() }
    }
    @Published private(set) var persistenceError: String?

    let fileURL: URL

    init(fileURL: URL? = nil) {
        let resolvedURL = fileURL ?? Self.defaultFileURL()
        let storedVersion = Self.storedSchemaVersion(at: resolvedURL)
        self.fileURL = resolvedURL
        self.settings = Self.load(from: resolvedURL)
        if storedVersion != nil, storedVersion != settings.schemaVersion {
            save()
        }
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return supportDirectory
            .appendingPathComponent("SpaceDownload", isDirectory: true)
            .appendingPathComponent("user_settings.json")
    }

    func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(settings).write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = "设置保存失败：\(error.localizedDescription)"
        }
    }

    private static func load(from fileURL: URL) -> DownloadSettings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? JSONDecoder().decode(DownloadSettings.self, from: data)
        else {
            return .defaults
        }
        return settings
    }

    private static func storedSchemaVersion(at fileURL: URL) -> Int? {
        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object["schema_version"] as? Int ?? 0
    }
}
