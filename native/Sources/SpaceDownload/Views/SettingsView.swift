import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case global = "全局设置"
    case sites = "站点设置"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .global: "slider.horizontal.3"
        case .sites: "square.stack.3d.up"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPage: SettingsPage = .global
    @State private var selectedSite: SiteID = .pornhub

    init(initialPage: SettingsPage = .global, initialSite: SiteID = .pornhub) {
        _selectedPage = State(initialValue: initialPage)
        _selectedSite = State(initialValue: initialSite)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(AppTheme.border)
            detail
        }
        .frame(width: 860, height: 640)
        .background(AppTheme.background)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SpaceDownload")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .padding(.horizontal, 12)
                .padding(.bottom, 18)

            ForEach(SettingsPage.allCases) { page in
                Button {
                    selectedPage = page
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: page.icon)
                            .frame(width: 18)
                        Text(page.rawValue)
                        Spacer()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectedPage == page ? .black : .white)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(
                        selectedPage == page ? AppTheme.orange : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
            Text("设置会自动保存")
                .font(.caption)
                .foregroundStyle(AppTheme.subdued)
                .padding(.horizontal, 12)
        }
        .padding(18)
        .frame(width: 205)
        .background(AppTheme.panel)
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedPage {
        case .global:
            GlobalSettingsPage(settingsStore: appState.settingsStore)
        case .sites:
            SiteSettingsPage(selectedSite: $selectedSite, settingsStore: appState.settingsStore)
        }
    }
}

private struct GlobalSettingsPage: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        SettingsPageContainer(
            title: "全局设置",
            subtitle: "所有站点共用的下载与网络参数"
        ) {
            SettingsCard(title: "下载") {
                SettingsRow(title: "保存目录", detail: "所有任务的默认保存位置") {
                    HStack(spacing: 8) {
                        TextField("保存目录", text: $settingsStore.settings.common.downloadPath)
                            .settingField()
                            .frame(width: 175)
                        Button("浏览") { appState.chooseDownloadDirectory() }
                            .buttonStyle(OrangeButtonStyle(compact: true))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                SettingsDivider()
                SettingsRow(title: "视频质量", detail: "站点支持范围内选择最高匹配质量") {
                    SettingsPicker(
                        selection: $settingsStore.settings.common.quality,
                        values: DownloadQuality.allCases
                    )
                }
                SettingsDivider()
                SettingsRow(title: "输出格式", detail: "下载完成后的封装或转码格式") {
                    SettingsPicker(
                        selection: $settingsStore.settings.common.outputFormat,
                        values: OutputFormat.allCases
                    )
                }
            }

            SettingsCard(title: "性能") {
                SettingsRow(title: "下载限速", detail: "不限速时使用当前网络可用带宽") {
                    SettingsPicker(
                        selection: $settingsStore.settings.common.rateLimit,
                        values: DownloadRateLimit.allCases
                    )
                }
                SettingsDivider()
                SettingsRow(title: "分片并发数", detail: "单个视频同时下载的分片数量，范围 1–16") {
                    Stepper(
                        value: $settingsStore.settings.common.concurrentFragments,
                        in: 1...16
                    ) {
                        Text("\(settingsStore.settings.common.concurrentFragments)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .frame(width: 28)
                    }
                    .frame(width: 112)
                }
            }

            SettingsCard(title: "网络") {
                SettingsRow(title: "代理", detail: "所有站点统一使用的 HTTP 或 SOCKS 代理") {
                    Toggle("", isOn: $settingsStore.settings.common.useProxy)
                        .labelsHidden()
                        .tint(AppTheme.orange)
                }
                if settingsStore.settings.common.useProxy {
                    SettingsDivider()
                    SettingsRow(title: "代理地址", detail: "例如 http://127.0.0.1:7890") {
                        TextField("代理地址", text: $settingsStore.settings.common.proxyURL)
                            .settingField()
                            .frame(width: 280)
                    }
                }
            }

            if let error = settingsStore.persistenceError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct SiteSettingsPage: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedSite: SiteID
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        SettingsPageContainer(
            title: "站点设置",
            subtitle: "每个站点独立保存命名、采集和认证规则"
        ) {
            siteSelector
            mediaSettings
            siteSpecificSettings

            if let error = settingsStore.persistenceError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var siteSelector: some View {
        SettingsCard(title: "当前站点") {
            Menu {
                ForEach(SiteID.allCases) { site in
                    Button {
                        selectedSite = site
                    } label: {
                        Label {
                            Text(site.displayName)
                        } icon: {
                            SiteIconView(siteID: site, size: 16)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    SiteIconView(siteID: selectedSite, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedSite.displayName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Text("编辑该站点的独立下载规则")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subdued)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.subdued)
                }
                .padding(.horizontal, 14)
                .frame(height: 56)
                .background(AppTheme.raisedPanel, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var mediaSettings: some View {
        SettingsCard(title: "文件与媒体") {
            SettingsRow(title: "文件命名模板", detail: "仅应用于 \(selectedSite.displayName)") {
                SettingsPicker(selection: filenameTemplate, values: FilenameTemplate.allCases)
            }
            if filenameTemplate.wrappedValue == .custom {
                SettingsDivider()
                SettingsRow(title: "自定义模板", detail: "使用 yt-dlp 模板字段") {
                    TextField("自定义模板", text: customTemplate)
                        .settingField()
                        .frame(width: 280)
                }
            } else if let rule = filenameTemplate.wrappedValue.rule {
                Text(rule)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(AppTheme.subdued)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 2)
            }
            SettingsDivider()
            SettingsRow(title: "标题翻译", detail: "下载前将标题翻译为中文") {
                Toggle("", isOn: translateTitle)
                    .labelsHidden()
                    .tint(AppTheme.orange)
            }
            SettingsDivider()
            SettingsRow(title: "下载封面", detail: "视频成功后保存同名最高可用封面") {
                Toggle("", isOn: embedThumbnail)
                    .labelsHidden()
                    .tint(AppTheme.orange)
            }
        }
    }

    @ViewBuilder
    private var siteSpecificSettings: some View {
        switch selectedSite {
        case .pornhub:
            SettingsCard(title: "Pornhub 采集") {
                SettingsRow(title: "批量网页分页", detail: "例如 1-3,5；留空下载全部页面") {
                    TextField("1-3,5", text: $settingsStore.settings.sites.pornhub.pageSelection)
                        .settingField()
                        .frame(width: 220)
                }
                SettingsDivider()
                SettingsRow(title: "账号", detail: "仅用于需要登录的内容") {
                    TextField("账号", text: $settingsStore.settings.sites.pornhub.username)
                        .settingField()
                        .frame(width: 220)
                }
                SettingsDivider()
                SettingsRow(title: "密码", detail: "仅保存在当前运行会话") {
                    SecureField("密码", text: $appState.password)
                        .settingField()
                        .frame(width: 220)
                }
                cookieSettings(
                    enabled: $settingsStore.settings.sites.pornhub.useCookies,
                    fileURL: appState.cookiesFileURL,
                    siteID: .pornhub
                )
            }
        case .youtube:
            SettingsCard(title: "YouTube 采集") {
                SettingsRow(title: "播放列表序号", detail: "例如 1-20,25；留空下载全部视频") {
                    TextField("1-20,25", text: $settingsStore.settings.sites.youtube.playlistSelection)
                        .settingField()
                        .frame(width: 220)
                }
                SettingsDivider()
                SettingsRow(title: "频道内容范围", detail: "频道链接需要采集的内容类型") {
                    SettingsPicker(
                        selection: $settingsStore.settings.sites.youtube.channelScope,
                        values: YouTubeChannelScope.allCases
                    )
                }
                SettingsDivider()
                SettingsRow(title: "视频编码偏好", detail: "自动模式优先选择综合最佳格式") {
                    SettingsPicker(
                        selection: $settingsStore.settings.sites.youtube.codecPreference,
                        values: YouTubeCodecPreference.allCases
                    )
                }
                SettingsDivider()
                SettingsRow(title: "字幕", detail: "下载人工字幕或自动生成字幕") {
                    SettingsPicker(
                        selection: $settingsStore.settings.sites.youtube.subtitleMode,
                        values: YouTubeSubtitleMode.allCases
                    )
                }
                if settingsStore.settings.sites.youtube.subtitleMode != .none {
                    SettingsDivider()
                    SettingsRow(title: "字幕语言", detail: "例如 zh-Hans,zh-Hant,en.*") {
                        TextField(
                            "zh-Hans,zh-Hant,en.*",
                            text: $settingsStore.settings.sites.youtube.subtitleLanguages
                        )
                        .settingField()
                        .frame(width: 240)
                    }
                }
                SettingsDivider()
                SettingsRow(title: "批量请求间隔", detail: "降低播放列表和频道请求频率") {
                    Stepper(
                        value: $settingsStore.settings.sites.youtube.requestIntervalSeconds,
                        in: 0...30
                    ) {
                        Text("\(settingsStore.settings.sites.youtube.requestIntervalSeconds) 秒")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .frame(width: 48)
                    }
                    .frame(width: 132)
                }
                cookieSettings(
                    enabled: $settingsStore.settings.sites.youtube.useCookies,
                    fileURL: appState.youtubeCookiesFileURL,
                    siteID: .youtube
                )
            }
        case .x:
            SettingsCard(title: "X 帖子") {
                Text("支持单条 status 链接中的视频、animated GIF 与多媒体资源。图片资源仅预留任务模型，尚未验证，当前不会宣称支持。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subdued)
                    .frame(maxWidth: .infinity, alignment: .leading)
                cookieSettings(
                    enabled: $settingsStore.settings.sites.x.useCookies,
                    fileURL: appState.xCookiesFileURL,
                    siteID: .x
                )
                Text("应用只使用你手动选择的 cookies.txt，不读取浏览器 Cookie。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subdued)
            }
        case .tiktok:
            SettingsCard(title: "TikTok 单视频") {
                Text("支持公开的 @用户/video/ID 链接，以及由 yt-dlp 安全解析重定向的 vm.tiktok.com / vt.tiktok.com 短链。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subdued)
                    .frame(maxWidth: .infinity, alignment: .leading)
                cookieSettings(
                    enabled: $settingsStore.settings.sites.tiktok.useCookies,
                    fileURL: appState.tiktokCookiesFileURL,
                    siteID: .tiktok
                )
                Text("公开内容通常无需 Cookies；应用只使用你手动选择的 cookies.txt，不读取 Chrome 或其他浏览器数据。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subdued)
            }
        case .douyin:
            SettingsCard(title: "抖音单视频") {
                Text("支持公开的 douyin.com/video/ID 标准链接，以及可安全交给 yt-dlp 解析的 v.douyin.com 短链。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subdued)
                    .frame(maxWidth: .infinity, alignment: .leading)
                cookieSettings(
                    enabled: $settingsStore.settings.sites.douyin.useCookies,
                    fileURL: appState.douyinCookiesFileURL,
                    siteID: .douyin
                )
                Text("仅使用你手动选择的抖音 cookies.txt；不会读取 Chrome 或其他浏览器认证，也不会复用 TikTok Cookies。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subdued)
            }
        }
    }

    private func cookieSettings(
        enabled: Binding<Bool>,
        fileURL: URL?,
        siteID: SiteID
    ) -> some View {
        Group {
            SettingsDivider()
            SettingsRow(title: "Cookies 文件", detail: "仅在你主动选择时使用，不保存文件路径") {
                HStack(spacing: 10) {
                    Toggle("", isOn: enabled)
                        .labelsHidden()
                        .tint(AppTheme.orange)
                    if enabled.wrappedValue {
                        Text(fileURL?.lastPathComponent ?? "未选择")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subdued)
                            .lineLimit(1)
                            .frame(width: 90, alignment: .trailing)
                        Button("选择") { appState.chooseCookiesFile(for: siteID) }
                            .buttonStyle(OrangeButtonStyle(compact: true))
                    }
                }
            }
        }
    }

    private var filenameTemplate: Binding<FilenameTemplate> {
        Binding(
            get: { media.filenameTemplate },
            set: { value in updateMedia { $0.filenameTemplate = value } }
        )
    }

    private var customTemplate: Binding<String> {
        Binding(
            get: { media.customTemplate },
            set: { value in updateMedia { $0.customTemplate = value } }
        )
    }

    private var translateTitle: Binding<Bool> {
        Binding(
            get: { media.translateTitle },
            set: { value in updateMedia { $0.translateTitle = value } }
        )
    }

    private var embedThumbnail: Binding<Bool> {
        Binding(
            get: { media.embedThumbnail },
            set: { value in updateMedia { $0.embedThumbnail = value } }
        )
    }

    private var media: SiteMediaSettings {
        settingsStore.settings.mediaSettings(for: selectedSite)
    }

    private func updateMedia(_ update: (inout SiteMediaSettings) -> Void) {
        switch selectedSite {
        case .pornhub: update(&settingsStore.settings.sites.pornhub.media)
        case .youtube: update(&settingsStore.settings.sites.youtube.media)
        case .x: update(&settingsStore.settings.sites.x.media)
        case .tiktok: update(&settingsStore.settings.sites.tiktok.media)
        case .douyin: update(&settingsStore.settings.sites.douyin.media)
        }
    }
}

struct SiteIconView: View {
    let siteID: SiteID
    var size: CGFloat = 22

    var body: some View {
        Image(nsImage: siteImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }

    private var siteImage: NSImage {
        let bundledURL = Bundle.main.url(forResource: siteID.iconResourceName, withExtension: "png", subdirectory: "SiteIcons")
            ?? Bundle.main.url(forResource: siteID.iconResourceName, withExtension: "svg", subdirectory: "SiteIcons")
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/SiteIcons/\(siteID.iconResourceName).\([.x, .tiktok, .douyin].contains(siteID) ? "svg" : "png")")
        guard let image = NSImage(contentsOf: bundledURL ?? sourceURL) else {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: siteID.displayName)
                ?? NSImage()
        }
        return image
    }
}

private struct SettingsPageContainer<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.subdued)
            }
            .padding(.horizontal, 30)
            .padding(.top, 26)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 16) {
                    content
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.orange)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel()
    }
}

private struct SettingsRow<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subdued)
            }
            Spacer(minLength: 16)
            content
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider().overlay(AppTheme.border)
    }
}

private struct SettingsPicker<Value>: View where Value: Hashable & Identifiable & RawRepresentable, Value.RawValue == String {
    @Binding var selection: Value
    let values: [Value]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(values) { value in
                Text(value.rawValue).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 190, alignment: .trailing)
    }
}

private struct SettingFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(AppTheme.raisedPanel, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border)
            }
    }
}

private extension View {
    func settingField() -> some View {
        modifier(SettingFieldModifier())
    }
}

struct OrangeButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 14 : 15, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, compact ? 14 : 22)
            .frame(height: compact ? 34 : 40)
            .background(AppTheme.orange.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
