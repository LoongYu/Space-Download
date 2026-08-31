import SwiftUI

struct MainDownloadView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            inputPanel
            statusPanel
            logPanel
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 22)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            if !appState.isSettingsVisible {
                Color.clear
                    .frame(width: 42, height: 1)
            }
            HStack(spacing: 0) {
                Text("Space")
                    .foregroundStyle(.white)
                Text("Download")
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.orange, in: RoundedRectangle(cornerRadius: 6))
            }
            .font(.system(size: 32, weight: .black, design: .rounded))

            Spacer()
            Text("原生版 · 下载引擎已接入")
                .font(.caption)
                .foregroundStyle(AppTheme.subdued)
        }
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("视频链接")
                .font(.system(size: 17, weight: .semibold))

            TextEditor(text: $appState.linkText)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 74, idealHeight: 82, maxHeight: 115)
                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border)
                }

            if let message = appState.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 24) {
                Button("开始下载") { appState.startDownload() }
                    .buttonStyle(OrangeButtonStyle())
                    .disabled(appState.taskCoordinator.status.isActive)

                Button("停止下载") { appState.stopDownload() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(appState.taskCoordinator.status != .running)

                Spacer()
                Text("已识别 \(appState.parsedLinks.count) 个链接")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subdued)
            }
        }
        .padding(18)
        .appPanel()
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(appState.taskCoordinator.status.label, systemImage: statusIcon)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(appState.taskCoordinator.currentIndex)/\(appState.taskCoordinator.totalCount)  ·  成功 \(appState.taskCoordinator.completedCount)  ·  失败 \(appState.taskCoordinator.failedCount)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subdued)
            }

            ProgressView(value: appState.taskCoordinator.progress)
                .tint(AppTheme.orange)

            HStack {
                Text(appState.taskCoordinator.currentTitle.isEmpty ? "下载进度" : appState.taskCoordinator.currentTitle)
                    .lineLimit(1)
                Spacer()
                Text("速度 \(appState.taskCoordinator.speed)  ·  剩余 \(appState.taskCoordinator.eta)")
            }
            .font(.caption)
            .foregroundStyle(AppTheme.subdued)
        }
        .padding(18)
        .appPanel()
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("运行日志")
                .font(.system(size: 17, weight: .semibold))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(appState.taskCoordinator.logs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .id(index)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .font(.system(size: 12.5, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                }
                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 9))
                .onChange(of: appState.taskCoordinator.logs.count) { _, count in
                    if count > 0 { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }
        }
        .padding(18)
        .frame(maxHeight: .infinity)
        .appPanel()
    }

    private var statusIcon: String {
        switch appState.taskCoordinator.status {
        case .idle: return "circle"
        case .running: return "arrow.down.circle.fill"
        case .stopping: return "stop.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(height: 40)
            .background(AppTheme.raisedPanel.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border)
            }
    }
}
