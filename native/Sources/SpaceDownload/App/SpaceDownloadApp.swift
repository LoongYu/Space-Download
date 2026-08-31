import SwiftUI

@main
struct SpaceDownloadApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 980, minHeight: 650)
        }
        .defaultSize(width: 1600, height: 900)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        .defaultSize(width: 860, height: 640)
        .windowResizability(.contentSize)
    }
}
