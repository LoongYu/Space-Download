import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            if appState.isSettingsVisible {
                SettingsView()
                    .frame(minWidth: 310, idealWidth: 340, maxWidth: 380)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            MainDownloadView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.background)
        .foregroundStyle(.white)
        .overlay(alignment: .topLeading) {
            if !appState.isSettingsVisible {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        appState.isSettingsVisible = true
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9))
                .padding(16)
                .help("展开设置")
            }
        }
        .preferredColorScheme(.dark)
    }
}
