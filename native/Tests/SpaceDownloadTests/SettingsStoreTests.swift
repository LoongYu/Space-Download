import Foundation
import XCTest
@testable import SpaceDownload

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testLoadsExistingPythonSettingsAndPersistsChanges() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("user_settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let existingJSON = """
        {
          "download_path": "/tmp/downloads",
          "saved_quality": "720p",
          "saved_out_format": "mkv",
          "saved_template_name": "作者/日期-标题(id)",
          "saved_custom_template": "%(title)s(%(id)s)",
          "saved_page_selection": "1-3,5",
          "saved_translate_title": true,
          "saved_embed_thumbnail": false,
          "saved_use_proxy": false,
          "saved_proxy_url": "http://127.0.0.1:7890",
          "saved_username": "tester",
          "saved_use_cookies": true
        }
        """
        try Data(existingJSON.utf8).write(to: fileURL)

        let store = SettingsStore(fileURL: fileURL)
        XCTAssertEqual(store.settings.downloadPath, "/tmp/downloads")
        XCTAssertEqual(store.settings.quality, .hd)
        XCTAssertEqual(store.settings.pageSelection, "1-3,5")

        store.settings.outputFormat = .webm
        let reloaded = SettingsStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.settings.outputFormat, .webm)
        XCTAssertEqual(reloaded.settings.schemaVersion, 2)

        let migratedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        )
        XCTAssertNotNil(migratedObject["common"])
        XCTAssertNotNil(migratedObject["sites"])
        XCTAssertNil(migratedObject["saved_page_selection"])
    }

    func testMissingFieldsUseDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("user_settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(#"{"saved_quality":"1080p"}"#.utf8).write(to: fileURL)

        let store = SettingsStore(fileURL: fileURL)
        XCTAssertEqual(store.settings.quality, .fullHD)
        XCTAssertEqual(store.settings.outputFormat, .mp4)
        XCTAssertFalse(store.settings.downloadPath.isEmpty)
    }

    func testPersistsIndependentYouTubeSettings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("user_settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SettingsStore(fileURL: fileURL)
        store.settings.selectedSite = .youtube
        store.settings.sites.youtube.playlistSelection = "1-10,20"
        store.settings.sites.youtube.channelScope = .shorts
        store.settings.sites.youtube.subtitleMode = .manualAndAuto
        store.settings.sites.youtube.codecPreference = .h264
        store.settings.sites.youtube.requestIntervalSeconds = 7
        store.settings.sites.youtube.authenticationMode = .chrome

        let reloaded = SettingsStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.settings.selectedSite, .youtube)
        XCTAssertEqual(reloaded.settings.sites.youtube.playlistSelection, "1-10,20")
        XCTAssertEqual(reloaded.settings.sites.youtube.channelScope, .shorts)
        XCTAssertEqual(reloaded.settings.sites.youtube.subtitleMode, .manualAndAuto)
        XCTAssertEqual(reloaded.settings.sites.youtube.codecPreference, .h264)
        XCTAssertEqual(reloaded.settings.sites.youtube.requestIntervalSeconds, 7)
        XCTAssertEqual(reloaded.settings.sites.youtube.resolvedAuthenticationMode, .chrome)
        XCTAssertEqual(reloaded.settings.sites.pornhub.pageSelection, "")
    }

    func testLegacyYouTubeCookiesSettingMigratesToCookiesFileAuthentication() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("user_settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var settings = DownloadSettings.defaults
        settings.sites.youtube.authenticationMode = nil
        settings.sites.youtube.useCookies = true
        try JSONEncoder().encode(settings).write(to: fileURL)

        let reloaded = SettingsStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.settings.sites.youtube.resolvedAuthenticationMode, .cookiesFile)
    }
}
