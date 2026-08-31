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

    func testGlobalSettingsWindowRendersAtExpectedSize() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let appState = AppState(
            settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        )
        let view = SettingsView(initialPage: .global)
            .environmentObject(appState)
            .frame(width: 860, height: 640)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 860, height: 640)
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.width, 860)
        XCTAssertEqual(hostingView.bounds.height, 640)

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
            .frame(width: 860, height: 640)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 860, height: 640)
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.width, 860)
        XCTAssertEqual(hostingView.bounds.height, 640)

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
        let view = SettingsView(initialPage: .sites, initialSite: .youtube)
            .environmentObject(appState)
            .frame(width: 860, height: 640)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 860, height: 640)
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        XCTAssertEqual(hostingView.bounds.width, 860)
        XCTAssertEqual(hostingView.bounds.height, 640)

        if let snapshotPath = ProcessInfo.processInfo.environment["SPACE_DOWNLOAD_YOUTUBE_SETTINGS_SNAPSHOT_PATH"] {
            let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try pngData.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
        }
    }
}
