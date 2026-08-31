import AppKit
import SwiftUI
import XCTest
@testable import SpaceDownload

@MainActor
final class InterfaceRenderTests: XCTestCase {
    func testDefaultWindowLayoutRendersAtExpectedSize() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let settingsURL = directory.appendingPathComponent("user_settings.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let appState = AppState(settingsStore: SettingsStore(fileURL: settingsURL))
        let view = ContentView()
            .environmentObject(appState)
            .frame(width: 1600, height: 900)

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 1600, height: 900)
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.width, 1600)
        XCTAssertEqual(hostingView.bounds.height, 900)
        XCTAssertEqual(Double(bitmap.pixelsWide) / Double(bitmap.pixelsHigh), 16.0 / 9.0, accuracy: 0.001)

        if let snapshotPath = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_SNAPSHOT_PATH"] {
            let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try pngData.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
        }
    }

    func testCollapsedSidebarLayoutStillRendersMainWindow() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let appState = AppState(
            settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        )
        appState.isSettingsVisible = false
        let view = ContentView()
            .environmentObject(appState)
            .frame(width: 1600, height: 900)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 1600, height: 900)
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.width, 1600)
        XCTAssertEqual(Double(bitmap.pixelsWide) / Double(bitmap.pixelsHigh), 16.0 / 9.0, accuracy: 0.001)
        XCTAssertFalse(appState.isSettingsVisible)

        if let snapshotPath = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_COLLAPSED_SNAPSHOT_PATH"] {
            let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try pngData.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
        }
    }

    func testYouTubeSettingsLayoutRendersAtExpectedSize() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let appState = AppState(
            settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        )
        appState.settingsStore.settings.selectedSite = .youtube
        appState.linkText = "https://www.youtube.com/playlist?list=PL123"
        let view = ContentView()
            .environmentObject(appState)
            .frame(width: 1600, height: 900)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 1600, height: 900)
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.width, 1600)
        XCTAssertEqual(Double(bitmap.pixelsWide) / Double(bitmap.pixelsHigh), 16.0 / 9.0, accuracy: 0.001)

        if let snapshotPath = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_YOUTUBE_SNAPSHOT_PATH"] {
            let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try pngData.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
        }
    }
}
