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

enum DownloadRateLimit: String, Codable, CaseIterable, Identifiable {
    case unlimited = "不限速"
    case oneMB = "1 MB/s"
    case twoMB = "2 MB/s"
    case fiveMB = "5 MB/s"
    case tenMB = "10 MB/s"
    case twentyMB = "20 MB/s"
    case fiftyMB = "50 MB/s"

    var id: String { rawValue }

    var ytDlpValue: String? {
        switch self {
        case .unlimited: nil
        case .oneMB: "1M"
        case .twoMB: "2M"
        case .fiveMB: "5M"
        case .tenMB: "10M"
        case .twentyMB: "20M"
        case .fiftyMB: "50M"
        }
    }
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
    case x
    case tiktok
    case douyin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pornhub: "Pornhub"
        case .youtube: "YouTube"
        case .x: "X"
        case .tiktok: "TikTok"
        case .douyin: "抖音"
        }
    }

    var iconResourceName: String { rawValue }
}

enum SiteSelection: String, Codable, CaseIterable, Identifiable {
    case automatic
    case pornhub
    case youtube
    case x
    case tiktok
    case douyin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "自动识别"
        case .pornhub: "Pornhub"
        case .youtube: "YouTube"
        case .x: "X"
        case .tiktok: "TikTok"
        case .douyin: "抖音"
        }
    }

    var siteID: SiteID? {
        switch self {
        case .automatic: nil
        case .pornhub: .pornhub
        case .youtube: .youtube
        case .x: .x
        case .tiktok: .tiktok
        case .douyin: .douyin
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

struct CommonDownloadSettings: Codable, Equatable {
    var downloadPath: String
    var quality: DownloadQuality
    var outputFormat: OutputFormat
    var rateLimit: DownloadRateLimit
    var concurrentFragments: Int
    var useProxy: Bool
    var proxyURL: String
}

struct SiteMediaSettings: Codable, Equatable {
    var filenameTemplate: FilenameTemplate
    var customTemplate: String
    var translateTitle: Bool
    var embedThumbnail: Bool

    var resolvedFilenameTemplate: String {
        filenameTemplate.rule ?? customTemplate
    }
}

struct PornhubSiteSettings: Codable, Equatable {
    var media: SiteMediaSettings
    var pageSelection: String
    var username: String
    var useCookies: Bool
}

struct YouTubeSiteSettings: Codable, Equatable {
    var media: SiteMediaSettings
    var playlistSelection: String
    var channelScope: YouTubeChannelScope
    var subtitleMode: YouTubeSubtitleMode
    var subtitleLanguages: String
    var codecPreference: YouTubeCodecPreference
    var requestIntervalSeconds: Int
    var useCookies: Bool
}

struct XSiteSettings: Codable, Equatable {
    var media: SiteMediaSettings
    var useCookies: Bool
}

struct TikTokSiteSettings: Codable, Equatable {
    var media: SiteMediaSettings
    var useCookies: Bool
}

struct DouyinSiteSettings: Codable, Equatable {
    var media: SiteMediaSettings
    var useCookies: Bool
}

struct PerSiteDownloadSettings: Codable, Equatable {
    var pornhub: PornhubSiteSettings
    var youtube: YouTubeSiteSettings
    var x: XSiteSettings
    var tiktok: TikTokSiteSettings
    var douyin: DouyinSiteSettings

    private enum CodingKeys: String, CodingKey { case pornhub, youtube, x, tiktok, douyin }

    init(pornhub: PornhubSiteSettings, youtube: YouTubeSiteSettings, x: XSiteSettings, tiktok: TikTokSiteSettings, douyin: DouyinSiteSettings) {
        self.pornhub = pornhub
        self.youtube = youtube
        self.x = x
        self.tiktok = tiktok
        self.douyin = douyin
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        pornhub = try values.decode(PornhubSiteSettings.self, forKey: .pornhub)
        youtube = try values.decode(YouTubeSiteSettings.self, forKey: .youtube)
        x = try values.decodeIfPresent(XSiteSettings.self, forKey: .x)
            ?? XSiteSettings(media: .defaults, useCookies: false)
        tiktok = try values.decodeIfPresent(TikTokSiteSettings.self, forKey: .tiktok)
            ?? TikTokSiteSettings(media: .tiktokDefaults, useCookies: false)
        douyin = try values.decodeIfPresent(DouyinSiteSettings.self, forKey: .douyin)
            ?? DouyinSiteSettings(media: .douyinDefaults, useCookies: false)
    }
}

extension DownloadSettings {
    func mediaSettings(for siteID: SiteID?) -> SiteMediaSettings {
        switch siteID {
        case .youtube: sites.youtube.media
        case .x: sites.x.media
        case .tiktok: sites.tiktok.media
        case .douyin: sites.douyin.media
        case .pornhub, .none: sites.pornhub.media
        }
    }
}

struct DownloadSettings: Codable, Equatable {
    var schemaVersion: Int
    var selectedSite: SiteSelection
    var common: CommonDownloadSettings
    var sites: PerSiteDownloadSettings

    static var defaults: DownloadSettings {
        DownloadSettings(
            schemaVersion: 5,
            selectedSite: .automatic,
            common: CommonDownloadSettings(
                downloadPath: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
                    ?? NSHomeDirectory() + "/Downloads",
                quality: .best,
                outputFormat: .mp4,
                rateLimit: .unlimited,
                concurrentFragments: 8,
                useProxy: false,
                proxyURL: "http://127.0.0.1:7890"
            ),
            sites: PerSiteDownloadSettings(
                pornhub: PornhubSiteSettings(
                    media: .defaults,
                    pageSelection: "",
                    username: "",
                    useCookies: false
                ),
                youtube: YouTubeSiteSettings(
                    media: .defaults,
                    playlistSelection: "",
                    channelScope: .videos,
                    subtitleMode: .none,
                    subtitleLanguages: "zh-Hans,zh-Hant,en.*",
                    codecPreference: .best,
                    requestIntervalSeconds: 5,
                    useCookies: false
                ),
                x: XSiteSettings(media: .defaults, useCookies: false),
                tiktok: TikTokSiteSettings(media: .tiktokDefaults, useCookies: false),
                douyin: DouyinSiteSettings(media: .douyinDefaults, useCookies: false)
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
            let storedVersion = try modern.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 2
            selectedSite = try modern.decodeIfPresent(SiteSelection.self, forKey: .selectedSite) ?? .automatic
            if storedVersion >= 3 {
                schemaVersion = 5
                common = try modern.decodeIfPresent(CommonDownloadSettings.self, forKey: .common) ?? defaults.common
                sites = try modern.decodeIfPresent(PerSiteDownloadSettings.self, forKey: .sites) ?? defaults.sites
            } else {
                let oldCommon = try modern.decodeIfPresent(V2CommonDownloadSettings.self, forKey: .common)
                let oldSites = try modern.decodeIfPresent(V2PerSiteDownloadSettings.self, forKey: .sites)
                let media = SiteMediaSettings(
                    filenameTemplate: oldCommon?.filenameTemplate ?? defaults.sites.pornhub.media.filenameTemplate,
                    customTemplate: oldCommon?.customTemplate ?? defaults.sites.pornhub.media.customTemplate,
                    translateTitle: oldCommon?.translateTitle ?? defaults.sites.pornhub.media.translateTitle,
                    embedThumbnail: oldCommon?.embedThumbnail ?? defaults.sites.pornhub.media.embedThumbnail
                )
                schemaVersion = 5
                common = CommonDownloadSettings(
                    downloadPath: oldCommon?.downloadPath ?? defaults.downloadPath,
                    quality: oldCommon?.quality ?? defaults.quality,
                    outputFormat: oldCommon?.outputFormat ?? defaults.outputFormat,
                    rateLimit: .unlimited,
                    concurrentFragments: 8,
                    useProxy: oldCommon?.useProxy ?? defaults.useProxy,
                    proxyURL: oldCommon?.proxyURL ?? defaults.proxyURL
                )
                sites = PerSiteDownloadSettings(
                    pornhub: PornhubSiteSettings(
                        media: media,
                        pageSelection: oldSites?.pornhub.pageSelection ?? defaults.pageSelection,
                        username: oldSites?.pornhub.username ?? defaults.username,
                        useCookies: oldSites?.pornhub.useCookies ?? defaults.useCookies
                    ),
                    youtube: YouTubeSiteSettings(
                        media: media,
                        playlistSelection: oldSites?.youtube.playlistSelection ?? defaults.sites.youtube.playlistSelection,
                        channelScope: oldSites?.youtube.channelScope ?? defaults.sites.youtube.channelScope,
                        subtitleMode: oldSites?.youtube.subtitleMode ?? defaults.sites.youtube.subtitleMode,
                        subtitleLanguages: oldSites?.youtube.subtitleLanguages ?? defaults.sites.youtube.subtitleLanguages,
                        codecPreference: oldSites?.youtube.codecPreference ?? defaults.sites.youtube.codecPreference,
                        requestIntervalSeconds: oldSites?.youtube.requestIntervalSeconds ?? defaults.sites.youtube.requestIntervalSeconds,
                        useCookies: oldSites?.youtube.useCookies ?? defaults.sites.youtube.useCookies
                    ),
                    x: defaults.sites.x,
                    tiktok: defaults.sites.tiktok,
                    douyin: defaults.sites.douyin
                )
            }
            return
        }

        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
        schemaVersion = 5
        selectedSite = .automatic
        let legacyMedia = SiteMediaSettings(
            filenameTemplate: try legacy.decodeIfPresent(FilenameTemplate.self, forKey: .filenameTemplate) ?? defaults.filenameTemplate,
            customTemplate: try legacy.decodeIfPresent(String.self, forKey: .customTemplate) ?? defaults.customTemplate,
            translateTitle: try legacy.decodeIfPresent(Bool.self, forKey: .translateTitle) ?? defaults.translateTitle,
            embedThumbnail: try legacy.decodeIfPresent(Bool.self, forKey: .embedThumbnail) ?? defaults.embedThumbnail
        )
        common = CommonDownloadSettings(
            downloadPath: try legacy.decodeIfPresent(String.self, forKey: .downloadPath) ?? defaults.downloadPath,
            quality: try legacy.decodeIfPresent(DownloadQuality.self, forKey: .quality) ?? defaults.quality,
            outputFormat: try legacy.decodeIfPresent(OutputFormat.self, forKey: .outputFormat) ?? defaults.outputFormat,
            rateLimit: .unlimited,
            concurrentFragments: 8,
            useProxy: try legacy.decodeIfPresent(Bool.self, forKey: .useProxy) ?? defaults.useProxy,
            proxyURL: try legacy.decodeIfPresent(String.self, forKey: .proxyURL) ?? defaults.proxyURL
        )
        sites = defaults.sites
        sites.pornhub = PornhubSiteSettings(
            media: legacyMedia,
            pageSelection: try legacy.decodeIfPresent(String.self, forKey: .pageSelection) ?? defaults.pageSelection,
            username: try legacy.decodeIfPresent(String.self, forKey: .username) ?? defaults.username,
            useCookies: try legacy.decodeIfPresent(Bool.self, forKey: .useCookies) ?? defaults.useCookies
        )
        sites.youtube.media = legacyMedia
    }
}

extension SiteMediaSettings {
    static let defaults = SiteMediaSettings(
        filenameTemplate: .uploaderDateTitle,
        customTemplate: "%(title)s(%(id)s)",
        translateTitle: true,
        embedThumbnail: true
    )

    // Verified against TikTok metadata: uploader, upload_date, title and id are populated.
    static let tiktokDefaults = SiteMediaSettings(
        filenameTemplate: .uploaderDateTitle,
        customTemplate: "%(uploader)s/%(upload_date)s-%(title)s(%(id)s)",
        translateTitle: false,
        embedThumbnail: true
    )

    // Anonymous live probing is currently blocked before metadata; keep the default
    // limited to the universally required title/id fields until Cookie-backed metadata is verified.
    static let douyinDefaults = SiteMediaSettings(
        filenameTemplate: .title,
        customTemplate: "%(title)s(%(id)s)",
        translateTitle: false,
        embedThumbnail: true
    )
}

private struct V2CommonDownloadSettings: Codable {
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

private struct V2PornhubSiteSettings: Codable {
    var pageSelection: String
    var username: String
    var useCookies: Bool
}

private struct V2YouTubeSiteSettings: Codable {
    var playlistSelection: String
    var channelScope: YouTubeChannelScope
    var subtitleMode: YouTubeSubtitleMode
    var subtitleLanguages: String
    var codecPreference: YouTubeCodecPreference
    var requestIntervalSeconds: Int
    var useCookies: Bool
}

private struct V2PerSiteDownloadSettings: Codable {
    var pornhub: V2PornhubSiteSettings
    var youtube: V2YouTubeSiteSettings
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
        get { sites.pornhub.media.filenameTemplate }
        set { sites.pornhub.media.filenameTemplate = newValue }
    }

    var customTemplate: String {
        get { sites.pornhub.media.customTemplate }
        set { sites.pornhub.media.customTemplate = newValue }
    }

    var translateTitle: Bool {
        get { sites.pornhub.media.translateTitle }
        set { sites.pornhub.media.translateTitle = newValue }
    }

    var embedThumbnail: Bool {
        get { sites.pornhub.media.embedThumbnail }
        set { sites.pornhub.media.embedThumbnail = newValue }
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
