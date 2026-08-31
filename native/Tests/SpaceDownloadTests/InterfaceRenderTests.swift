import AppKit
import SwiftUI
import XCTest
@testable import SpaceDownload

@MainActor
final class InterfaceRenderTests: XCTestCase {
    private let settingsSize = NSSize(width: 960, height: 840)

    func testSiteMenuIconsUseFixedLogicalSize() {
        for site in SiteID.allCases {
            let image = SiteIconView(siteID: site, size: 16).renderedImage
            XCTAssertEqual(image.size, NSSize(width: 16, height: 16), "Unexpected menu icon size for \(site)")
        }
    }

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

    func testGlobalSettingsWindowRendersAtExpectedSize() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let appState = AppState(
            settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        )
        appState.settingsStore.settings.common.useProxy = true
        let view = SettingsView(initialPage: .global)
            .environmentObject(appState)
            .frame(width: settingsSize.width, height: settingsSize.height)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: settingsSize)
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.size, settingsSize)
        XCTAssertFalse(containsScrollView(hostingView))

        if let snapshotPath = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_GLOBAL_SETTINGS_SNAPSHOT_PATH"] {
            let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try pngData.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
        }
    }

    func testPornhubSettingsWindowRendersAtExpectedSize() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let appState = AppState(
            settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        )
        let view = SettingsView(initialPage: .sites, initialSite: .pornhub)
            .environmentObject(appState)
            .frame(width: settingsSize.width, height: settingsSize.height)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: settingsSize)
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.size, settingsSize)
        XCTAssertFalse(containsScrollView(hostingView))

        if let snapshotPath = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_PORNHUB_SETTINGS_SNAPSHOT_PATH"] {
            let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try pngData.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
        }
    }

    func testYouTubeSettingsWindowRendersAtExpectedSize() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let appState = AppState(
            settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        )
        appState.settingsStore.settings.sites.youtube.subtitleMode = .manualAndAuto
        appState.settingsStore.settings.sites.youtube.useCookies = true
        let view = SettingsView(initialPage: .sites, initialSite: .youtube)
            .environmentObject(appState)
            .frame(width: settingsSize.width, height: settingsSize.height)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: settingsSize)
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.size, settingsSize)
        XCTAssertFalse(containsScrollView(hostingView))

        if let snapshotPath = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_YOUTUBE_SETTINGS_SNAPSHOT_PATH"] {
            let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try pngData.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
        }
    }

    func testXSettingsWindowRendersAndCanWriteSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let appState = AppState(settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json")))
        let view = SettingsView(initialPage: .sites, initialSite: .x).environmentObject(appState).frame(width: settingsSize.width, height: settingsSize.height)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: settingsSize)
        hostingView.layoutSubtreeIfNeeded()
        XCTAssertFalse(containsScrollView(hostingView))
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        if let path = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_X_SETTINGS_SNAPSHOT_PATH"] {
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
    }

    func testTikTokSettingsWindowRendersAndCanWriteSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let appState = AppState(settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json")))
        let view = SettingsView(initialPage: .sites, initialSite: .tiktok).environmentObject(appState).frame(width: settingsSize.width, height: settingsSize.height)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: settingsSize)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.size, settingsSize)
        XCTAssertFalse(containsScrollView(hostingView))
        if let path = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_TIKTOK_SETTINGS_SNAPSHOT_PATH"] {
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
    }

    func testDouyinSettingsWindowRendersAndCanWriteSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let appState = AppState(settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json")))
        let view = SettingsView(initialPage: .sites, initialSite: .douyin).environmentObject(appState).frame(width: settingsSize.width, height: settingsSize.height)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: settingsSize)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.size, settingsSize)
        XCTAssertFalse(containsScrollView(hostingView))
        if let path = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_DOUYIN_SETTINGS_SNAPSHOT_PATH"] {
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
    }

    func testInstagramSettingsWindowRendersAndCanWriteSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let appState = AppState(settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json")))
        let view = SettingsView(initialPage: .sites, initialSite: .instagram).environmentObject(appState).frame(width: settingsSize.width, height: settingsSize.height)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: settingsSize)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.size, settingsSize)
        XCTAssertFalse(containsScrollView(hostingView))
        if let path = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_INSTAGRAM_SETTINGS_SNAPSHOT_PATH"] {
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
    }

    func testTelegramSettingsWindowRendersAndCanWriteSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let appState = AppState(settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json")))
        let view = SettingsView(initialPage: .sites, initialSite: .telegram).environmentObject(appState).frame(width: settingsSize.width, height: settingsSize.height)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: settingsSize)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.size, settingsSize)
        XCTAssertFalse(containsScrollView(hostingView))
        if let path = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_TELEGRAM_SETTINGS_SNAPSHOT_PATH"] {
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
    }

    private func containsScrollView(_ view: NSView) -> Bool {
        if view is NSScrollView { return true }
        return view.subviews.contains(where: containsScrollView)
    }
}
