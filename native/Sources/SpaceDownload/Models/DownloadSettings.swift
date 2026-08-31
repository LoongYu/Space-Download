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

enum SiteID: String, Codable, CaseIterable, Identifiable {
    case pornhub
    case youtube

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pornhub: "Pornhub"
        case .youtube: "YouTube"
        }
    }
}

enum SiteSelection: String, Codable, CaseIterable, Identifiable {
    case automatic
    case pornhub
    case youtube

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "自动识别"
        case .pornhub: "Pornhub"
        case .youtube: "YouTube"
        }
    }

    var siteID: SiteID? {
        switch self {
        case .automatic: nil
        case .pornhub: .pornhub
        case .youtube: .youtube
        }
    }
}

enum YouTubeChannelScope: String, Codable, CaseIterable, Identifiable {
    case all = "全部内容"
    case videos = "视频"
    case shorts = "Shorts"
    case streams = "直播"

    var id: String { rawValue }
}

enum YouTubeSubtitleMode: String, Codable, CaseIterable, Identifiable {
    case none = "不下载字幕"
    case manual = "人工字幕"
    case manualAndAuto = "人工和自动字幕"

    var id: String { rawValue }
}

enum YouTubeCodecPreference: String, Codable, CaseIterable, Identifiable {
    case best = "自动选择"
    case h264 = "H.264 兼容优先"
    case vp9 = "VP9 优先"
    case av1 = "AV1 优先"

    var id: String { rawValue }

    var ytDlpSortValue: String? {
        switch self {
        case .best: nil
        case .h264: "vcodec:h264"
        case .vp9: "vcodec:vp9"
        case .av1: "vcodec:av01"
        }
    }
}

enum YouTubeAuthenticationMode: String, Codable, CaseIterable, Identifiable {
    case none = "无需认证"
    case cookiesFile = "Cookies 文件"
    case chrome = "Chrome 浏览器"

    var id: String { rawValue }
}

struct CommonDownloadSettings: Codable, Equatable {
    var downloadPath: String
    var quality: DownloadQuality
    var outputFormat: OutputFormat
    var filenameTemplate: FilenameTemplate
    var customTemplate: String
    var translateTitle: Bool
    var embedThumbnail: Bool
    var useProxy: Bool
    var proxyURL: String
}

struct PornhubSiteSettings: Codable, Equatable {
    var pageSelection: String
    var username: String
    var useCookies: Bool
}

struct YouTubeSiteSettings: Codable, Equatable {
    var playlistSelection: String
    var channelScope: YouTubeChannelScope
    var subtitleMode: YouTubeSubtitleMode
    var subtitleLanguages: String
    var codecPreference: YouTubeCodecPreference
    var requestIntervalSeconds: Int
    var useCookies: Bool
    var authenticationMode: YouTubeAuthenticationMode?

    var resolvedAuthenticationMode: YouTubeAuthenticationMode {
        authenticationMode ?? (useCookies ? .cookiesFile : .none)
    }
}

struct PerSiteDownloadSettings: Codable, Equatable {
    var pornhub: PornhubSiteSettings
    var youtube: YouTubeSiteSettings
}

extension DownloadSettings {
    var resolvedFilenameTemplate: String {
        filenameTemplate.rule ?? customTemplate
    }
}

struct DownloadSettings: Codable, Equatable {
    var schemaVersion: Int
    var selectedSite: SiteSelection
    var common: CommonDownloadSettings
    var sites: PerSiteDownloadSettings

    static var defaults: DownloadSettings {
        DownloadSettings(
            schemaVersion: 2,
            selectedSite: .automatic,
            common: CommonDownloadSettings(
                downloadPath: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
                    ?? NSHomeDirectory() + "/Downloads",
                quality: .best,
                outputFormat: .mp4,
                filenameTemplate: .uploaderDateTitle,
                customTemplate: "%(title)s(%(id)s)",
                translateTitle: true,
                embedThumbnail: true,
                useProxy: false,
                proxyURL: "http://127.0.0.1:7890"
            ),
            sites: PerSiteDownloadSettings(
                pornhub: PornhubSiteSettings(pageSelection: "", username: "", useCookies: false),
                youtube: YouTubeSiteSettings(
                    playlistSelection: "",
                    channelScope: .videos,
                    subtitleMode: .none,
                    subtitleLanguages: "zh-Hans,zh-Hant,en.*",
                    codecPreference: .best,
                    requestIntervalSeconds: 5,
                    useCookies: false,
                    authenticationMode: YouTubeAuthenticationMode.none
                )
            )
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case selectedSite = "selected_site"
        case common
        case sites
    }

    private enum LegacyCodingKeys: String, CodingKey {
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
        schemaVersion: Int,
        selectedSite: SiteSelection,
        common: CommonDownloadSettings,
        sites: PerSiteDownloadSettings
    ) {
        self.schemaVersion = schemaVersion
        self.selectedSite = selectedSite
        self.common = common
        self.sites = sites
    }

    init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        let modern = try decoder.container(keyedBy: CodingKeys.self)
        if modern.contains(.common) || modern.contains(.sites) {
            schemaVersion = try modern.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 2
            selectedSite = try modern.decodeIfPresent(SiteSelection.self, forKey: .selectedSite) ?? .automatic
            common = try modern.decodeIfPresent(CommonDownloadSettings.self, forKey: .common) ?? defaults.common
            sites = try modern.decodeIfPresent(PerSiteDownloadSettings.self, forKey: .sites) ?? defaults.sites
            return
        }

        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
        schemaVersion = 2
        selectedSite = .automatic
        common = CommonDownloadSettings(
            downloadPath: try legacy.decodeIfPresent(String.self, forKey: .downloadPath) ?? defaults.downloadPath,
            quality: try legacy.decodeIfPresent(DownloadQuality.self, forKey: .quality) ?? defaults.quality,
            outputFormat: try legacy.decodeIfPresent(OutputFormat.self, forKey: .outputFormat) ?? defaults.outputFormat,
            filenameTemplate: try legacy.decodeIfPresent(FilenameTemplate.self, forKey: .filenameTemplate) ?? defaults.filenameTemplate,
            customTemplate: try legacy.decodeIfPresent(String.self, forKey: .customTemplate) ?? defaults.customTemplate,
            translateTitle: try legacy.decodeIfPresent(Bool.self, forKey: .translateTitle) ?? defaults.translateTitle,
            embedThumbnail: try legacy.decodeIfPresent(Bool.self, forKey: .embedThumbnail) ?? defaults.embedThumbnail,
            useProxy: try legacy.decodeIfPresent(Bool.self, forKey: .useProxy) ?? defaults.useProxy,
            proxyURL: try legacy.decodeIfPresent(String.self, forKey: .proxyURL) ?? defaults.proxyURL
        )
        sites = defaults.sites
        sites.pornhub = PornhubSiteSettings(
            pageSelection: try legacy.decodeIfPresent(String.self, forKey: .pageSelection) ?? defaults.pageSelection,
            username: try legacy.decodeIfPresent(String.self, forKey: .username) ?? defaults.username,
            useCookies: try legacy.decodeIfPresent(Bool.self, forKey: .useCookies) ?? defaults.useCookies
        )
    }
}

extension DownloadSettings {
    var downloadPath: String {
        get { common.downloadPath }
        set { common.downloadPath = newValue }
    }

    var quality: DownloadQuality {
        get { common.quality }
        set { common.quality = newValue }
    }

    var outputFormat: OutputFormat {
        get { common.outputFormat }
        set { common.outputFormat = newValue }
    }

    var filenameTemplate: FilenameTemplate {
        get { common.filenameTemplate }
        set { common.filenameTemplate = newValue }
    }

    var customTemplate: String {
        get { common.customTemplate }
        set { common.customTemplate = newValue }
    }

    var translateTitle: Bool {
        get { common.translateTitle }
        set { common.translateTitle = newValue }
    }

    var embedThumbnail: Bool {
        get { common.embedThumbnail }
        set { common.embedThumbnail = newValue }
    }

    var useProxy: Bool {
        get { common.useProxy }
        set { common.useProxy = newValue }
    }

    var proxyURL: String {
        get { common.proxyURL }
        set { common.proxyURL = newValue }
    }

    var pageSelection: String {
        get { sites.pornhub.pageSelection }
        set { sites.pornhub.pageSelection = newValue }
    }

    var username: String {
        get { sites.pornhub.username }
        set { sites.pornhub.username = newValue }
    }

    var useCookies: Bool {
        get { sites.pornhub.useCookies }
        set { sites.pornhub.useCookies = newValue }
    }
}
