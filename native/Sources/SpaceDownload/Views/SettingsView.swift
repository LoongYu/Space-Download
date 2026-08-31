import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsViewContent(settingsStore: appState.settingsStore)
    }
}

private struct SettingsViewContent: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        _settingsStore = ObservedObject(wrappedValue: settingsStore)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设置")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        appState.isSettingsVisible = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.plain)
                .help("收起设置")
            }
            .padding(.horizontal, 22)
            .padding(.top, 26)
            .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    sitePicker
                    Label(appState.detectedSiteLabel, systemImage: siteIcon)
                        .font(.caption)
                        .foregroundStyle(AppTheme.orange)

                    sectionLabel("通用设置")
                    picker("视频质量", selection: $settingsStore.settings.quality, values: DownloadQuality.allCases)
                    picker("输出视频格式", selection: $settingsStore.settings.outputFormat, values: OutputFormat.allCases)

                    settingLabel("保存目录")
                    HStack(spacing: 8) {
                        TextField("保存目录", text: $settingsStore.settings.downloadPath)
                            .settingField()
                        Button("浏览") {
                            appState.chooseDownloadDirectory()
                        }
                        .buttonStyle(OrangeButtonStyle(compact: true))
                    }

                    picker("文件命名模板", selection: $settingsStore.settings.filenameTemplate, values: FilenameTemplate.allCases)
                    if settingsStore.settings.filenameTemplate == .custom {
                        TextField("自定义模板", text: $settingsStore.settings.customTemplate)
                            .settingField()
                    } else if let rule = settingsStore.settings.filenameTemplate.rule {
                        Text(rule)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppTheme.subdued)
                            .textSelection(.enabled)
                    }

                    Toggle("翻译标题为中文", isOn: $settingsStore.settings.translateTitle)
                        .tint(AppTheme.orange)
                    Toggle("写入封面图", isOn: $settingsStore.settings.embedThumbnail)
                        .tint(AppTheme.orange)
                    Toggle("启用代理", isOn: $settingsStore.settings.useProxy)
                        .tint(AppTheme.orange)

                    if settingsStore.settings.useProxy {
                        TextField("代理地址", text: $settingsStore.settings.proxyURL)
                            .settingField()
                    }

                    Divider().overlay(AppTheme.border)
                    sectionLabel("\(appState.activeSettingsSite.displayName) 设置")
                    siteSpecificSettings

                    if let error = settingsStore.persistenceError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
        }
        .background(AppTheme.panel)
        .overlay(alignment: .trailing) {
            Rectangle().fill(AppTheme.border).frame(width: 1)
        }
    }

    @ViewBuilder
    private var siteSpecificSettings: some View {
        switch appState.activeSettingsSite {
        case .pornhub:
            settingLabel("批量网页分页")
            TextField(
                "例如 1-3,5；留空下载全部",
                text: $settingsStore.settings.sites.pornhub.pageSelection
            )
            .settingField()

            DisclosureGroup("账号认证（可选）") {
                VStack(spacing: 10) {
                    TextField("账号", text: $settingsStore.settings.sites.pornhub.username)
                        .settingField()
                    SecureField("密码（不会保存）", text: $appState.password)
                        .settingField()
                    cookiesPicker(
                        enabled: $settingsStore.settings.sites.pornhub.useCookies,
                        fileURL: appState.cookiesFileURL,
                        siteID: .pornhub
                    )
                }
                .padding(.top, 10)
            }

        case .youtube:
            settingLabel("播放列表序号")
            TextField(
                "例如 1-20,25；留空下载全部",
                text: $settingsStore.settings.sites.youtube.playlistSelection
            )
            .settingField()

            picker(
                "频道内容范围",
                selection: $settingsStore.settings.sites.youtube.channelScope,
                values: YouTubeChannelScope.allCases
            )
            picker(
                "视频编码偏好",
                selection: $settingsStore.settings.sites.youtube.codecPreference,
                values: YouTubeCodecPreference.allCases
            )
            picker(
                "字幕",
                selection: $settingsStore.settings.sites.youtube.subtitleMode,
                values: YouTubeSubtitleMode.allCases
            )
            if settingsStore.settings.sites.youtube.subtitleMode != .none {
                settingLabel("字幕语言")
                TextField(
                    "例如 zh-Hans,zh-Hant,en.*",
                    text: $settingsStore.settings.sites.youtube.subtitleLanguages
                )
                .settingField()
            }
            Stepper(
                "批量请求间隔 \(settingsStore.settings.sites.youtube.requestIntervalSeconds) 秒",
                value: $settingsStore.settings.sites.youtube.requestIntervalSeconds,
                in: 0...30
            )
            .font(.system(size: 13, weight: .semibold))

            picker(
                "认证方式",
                selection: youtubeAuthenticationBinding,
                values: YouTubeAuthenticationMode.allCases
            )
            if settingsStore.settings.sites.youtube.resolvedAuthenticationMode == .cookiesFile {
                HStack(spacing: 8) {
                    Text(appState.youtubeCookiesFileURL?.lastPathComponent ?? "未选择文件")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subdued)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("选择") { appState.chooseCookiesFile(for: .youtube) }
                        .buttonStyle(OrangeButtonStyle(compact: true))
                }
            } else if settingsStore.settings.sites.youtube.resolvedAuthenticationMode == .chrome {
                Text("仅在下载时由 yt-dlp 读取本机 Chrome 会话，不保存 Cookies。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subdued)
            }
        }
    }

    private var youtubeAuthenticationBinding: Binding<YouTubeAuthenticationMode> {
        Binding(
            get: { settingsStore.settings.sites.youtube.resolvedAuthenticationMode },
            set: { mode in
                settingsStore.settings.sites.youtube.authenticationMode = mode
                settingsStore.settings.sites.youtube.useCookies = mode == .cookiesFile
            }
        )
    }

    private func cookiesPicker(
        enabled: Binding<Bool>,
        fileURL: URL?,
        siteID: SiteID
    ) -> some View {
        VStack(spacing: 10) {
            Toggle("使用 Cookies 文件", isOn: enabled)
                .tint(AppTheme.orange)
            if enabled.wrappedValue {
                HStack(spacing: 8) {
                    Text(fileURL?.lastPathComponent ?? "未选择文件")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subdued)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("选择") { appState.chooseCookiesFile(for: siteID) }
                        .buttonStyle(OrangeButtonStyle(compact: true))
                }
            }
        }
    }

    private var siteIcon: String {
        appState.activeSettingsSite == .youtube ? "play.rectangle.fill" : "globe"
    }

    private var sitePicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            settingLabel("站点设置")
            Menu {
                ForEach(SiteSelection.allCases) { site in
                    Button(site.displayName) {
                        settingsStore.settings.selectedSite = site
                    }
                }
            } label: {
                HStack {
                    Text(settingsStore.settings.selectedSite.displayName)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.subdued)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .background(AppTheme.raisedPanel, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border)
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(AppTheme.orange)
    }

    private func settingLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.subdued)
    }

    private func picker<Value: Hashable & Identifiable & RawRepresentable>(
        _ label: String,
        selection: Binding<Value>,
        values: [Value]
    ) -> some View where Value.RawValue == String {
        VStack(alignment: .leading, spacing: 7) {
            settingLabel(label)
            Menu {
                ForEach(values) { value in
                    Button(value.rawValue) {
                        selection.wrappedValue = value
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.rawValue)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.subdued)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .background(AppTheme.raisedPanel, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border)
            }
        }
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
