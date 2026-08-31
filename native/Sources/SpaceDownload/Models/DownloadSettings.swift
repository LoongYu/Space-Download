import Foundation

enum DownloadQuality: String, Codable, CaseIterable, Identifiable {
    case best = "最佳"
    case ultraHD = "4K (2160p)"
    case quadHD = "2K (1440p)"
    case fullHD = "1080p"
    case hd = "720p"
    case standard = "480p"

    var id: String { rawValue }

    var ytDlpFormat: String {
        switch self {
        case .best: return "bestvideo+bestaudio/best"
        case .ultraHD: return "bestvideo[height<=2160]+bestaudio/best[height<=2160]"
        case .quadHD: return "bestvideo[height<=1440]+bestaudio/best[height<=1440]"
        case .fullHD: return "bestvideo[height<=1080]+bestaudio/best[height<=1080]"
        case .hd: return "bestvideo[height<=720]+bestaudio/best[height<=720]"
        case .standard: return "bestvideo[height<=480]+bestaudio/best[height<=480]"
        }
    }
}

enum OutputFormat: String, Codable, CaseIterable, Identifiable {
    case mp4, mkv, webm, flv

    var id: String { rawValue }
}

enum FilenameTemplate: String, Codable, CaseIterable, Identifiable {
    case title = "仅标题(id)"
    case uploaderTitle = "作者-标题(id)"
    case dateTitle = "日期-标题(id)"
    case uploaderDateTitle = "作者/日期-标题(id)"
    case uploaderFolderTitle = "作者/标题(id)"
    case custom = "自定义"

    var id: String { rawValue }

    var rule: String? {
        switch self {
        case .title: return "%(title)s(%(id)s)"
        case .uploaderTitle: return "%(uploader)s-%(title)s(%(id)s)"
        case .dateTitle: return "%(upload_date)s-%(title)s(%(id)s)"
        case .uploaderDateTitle: return "%(uploader)s/%(upload_date)s-%(title)s(%(id)s)"
        case .uploaderFolderTitle: return "%(uploader)s/%(title)s(%(id)s)"
        case .custom: return nil
        }
    }
}

extension DownloadSettings {
    var resolvedFilenameTemplate: String {
        filenameTemplate.rule ?? customTemplate
    }
}

struct DownloadSettings: Codable, Equatable {
    var downloadPath: String
    var quality: DownloadQuality
    var outputFormat: OutputFormat
    var filenameTemplate: FilenameTemplate
    var customTemplate: String
    var pageSelection: String
    var translateTitle: Bool
    var embedThumbnail: Bool
    var useProxy: Bool
    var proxyURL: String
    var username: String
    var useCookies: Bool

    static var defaults: DownloadSettings {
        DownloadSettings(
            downloadPath: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
                ?? NSHomeDirectory() + "/Downloads",
            quality: .best,
            outputFormat: .mp4,
            filenameTemplate: .uploaderDateTitle,
            customTemplate: "%(title)s(%(id)s)",
            pageSelection: "",
            translateTitle: true,
            embedThumbnail: true,
            useProxy: false,
            proxyURL: "http://127.0.0.1:7890",
            username: "",
            useCookies: false
        )
    }

    enum CodingKeys: String, CodingKey {
        case downloadPath = "download_path"
        case quality = "saved_quality"
        case outputFormat = "saved_out_format"
        case filenameTemplate = "saved_template_name"
        case customTemplate = "saved_custom_template"
        case pageSelection = "saved_page_selection"
        case translateTitle = "saved_translate_title"
        case embedThumbnail = "saved_embed_thumbnail"
        case useProxy = "saved_use_proxy"
        case proxyURL = "saved_proxy_url"
        case username = "saved_username"
        case useCookies = "saved_use_cookies"
    }

    init(
        downloadPath: String,
        quality: DownloadQuality,
        outputFormat: OutputFormat,
        filenameTemplate: FilenameTemplate,
        customTemplate: String,
        pageSelection: String,
        translateTitle: Bool,
        embedThumbnail: Bool,
        useProxy: Bool,
        proxyURL: String,
        username: String,
        useCookies: Bool
    ) {
        self.downloadPath = downloadPath
        self.quality = quality
        self.outputFormat = outputFormat
        self.filenameTemplate = filenameTemplate
        self.customTemplate = customTemplate
        self.pageSelection = pageSelection
        self.translateTitle = translateTitle
        self.embedThumbnail = embedThumbnail
        self.useProxy = useProxy
        self.proxyURL = proxyURL
        self.username = username
        self.useCookies = useCookies
    }

    init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        let container = try decoder.container(keyedBy: CodingKeys.self)
        downloadPath = try container.decodeIfPresent(String.self, forKey: .downloadPath) ?? defaults.downloadPath
        quality = try container.decodeIfPresent(DownloadQuality.self, forKey: .quality) ?? defaults.quality
        outputFormat = try container.decodeIfPresent(OutputFormat.self, forKey: .outputFormat) ?? defaults.outputFormat
        filenameTemplate = try container.decodeIfPresent(FilenameTemplate.self, forKey: .filenameTemplate) ?? defaults.filenameTemplate
        customTemplate = try container.decodeIfPresent(String.self, forKey: .customTemplate) ?? defaults.customTemplate
        pageSelection = try container.decodeIfPresent(String.self, forKey: .pageSelection) ?? defaults.pageSelection
        translateTitle = try container.decodeIfPresent(Bool.self, forKey: .translateTitle) ?? defaults.translateTitle
        embedThumbnail = try container.decodeIfPresent(Bool.self, forKey: .embedThumbnail) ?? defaults.embedThumbnail
        useProxy = try container.decodeIfPresent(Bool.self, forKey: .useProxy) ?? defaults.useProxy
        proxyURL = try container.decodeIfPresent(String.self, forKey: .proxyURL) ?? defaults.proxyURL
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? defaults.username
        useCookies = try container.decodeIfPresent(Bool.self, forKey: .useCookies) ?? defaults.useCookies
    }
}
