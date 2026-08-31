import Foundation
import XCTest
@testable import SpaceDownload

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testSchemaFourSettingsMigrateTikTokDefaultsWithoutChangingExistingSites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("settings.json")
        var existing = DownloadSettings.defaults
        existing.sites.pornhub.media.translateTitle = false
        existing.sites.youtube.requestIntervalSeconds = 9
        existing.sites.x.useCookies = true
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(existing)) as! [String: Any]
        var sites = object["sites"] as! [String: Any]
        sites.removeValue(forKey: "tiktok")
        var legacy = object
        legacy["sites"] = sites
        try JSONSerialization.data(withJSONObject: legacy).write(to: file)

        let migrated = SettingsStore(fileURL: file).settings
        XCTAssertEqual(migrated.schemaVersion, 5)
        XCTAssertFalse(migrated.sites.pornhub.media.translateTitle)
        XCTAssertEqual(migrated.sites.youtube.requestIntervalSeconds, 9)
        XCTAssertTrue(migrated.sites.x.useCookies)
        XCTAssertEqual(migrated.sites.tiktok.media, .tiktokDefaults)
        XCTAssertFalse(migrated.sites.tiktok.useCookies)
    }
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
        XCTAssertEqual(reloaded.settings.schemaVersion, 5)
        XCTAssertEqual(reloaded.settings.sites.pornhub.media.filenameTemplate, .uploaderDateTitle)
        XCTAssertEqual(reloaded.settings.sites.youtube.media.filenameTemplate, .uploaderDateTitle)
        XCTAssertTrue(reloaded.settings.sites.pornhub.media.translateTitle)
        XCTAssertTrue(reloaded.settings.sites.youtube.media.translateTitle)

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
        store.settings.sites.youtube.useCookies = true
        store.settings.sites.youtube.media.filenameTemplate = .title
        store.settings.sites.youtube.media.translateTitle = false

        let reloaded = SettingsStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.settings.selectedSite, .youtube)
        XCTAssertEqual(reloaded.settings.sites.youtube.playlistSelection, "1-10,20")
        XCTAssertEqual(reloaded.settings.sites.youtube.channelScope, .shorts)
        XCTAssertEqual(reloaded.settings.sites.youtube.subtitleMode, .manualAndAuto)
        XCTAssertEqual(reloaded.settings.sites.youtube.codecPreference, .h264)
        XCTAssertEqual(reloaded.settings.sites.youtube.requestIntervalSeconds, 7)
        XCTAssertTrue(reloaded.settings.sites.youtube.useCookies)
        XCTAssertEqual(reloaded.settings.sites.youtube.media.filenameTemplate, .title)
        XCTAssertFalse(reloaded.settings.sites.youtube.media.translateTitle)
        XCTAssertEqual(reloaded.settings.sites.pornhub.media.filenameTemplate, .uploaderDateTitle)
        XCTAssertTrue(reloaded.settings.sites.pornhub.media.translateTitle)
        XCTAssertEqual(reloaded.settings.sites.pornhub.pageSelection, "")
    }

    func testPersistsIndependentXSettingsWithoutChangingExistingSites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("user_settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SettingsStore(fileURL: fileURL)
        store.settings.selectedSite = .x
        store.settings.sites.x.useCookies = true
        store.settings.sites.x.media.filenameTemplate = .title
        store.settings.sites.x.media.translateTitle = false

        let reloaded = SettingsStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.settings.selectedSite, .x)
        XCTAssertTrue(reloaded.settings.sites.x.useCookies)
        XCTAssertEqual(reloaded.settings.sites.x.media.filenameTemplate, .title)
        XCTAssertFalse(reloaded.settings.sites.x.media.translateTitle)
        XCTAssertEqual(reloaded.settings.sites.youtube.media.filenameTemplate, .uploaderDateTitle)
        XCTAssertEqual(reloaded.settings.sites.pornhub.media.filenameTemplate, .uploaderDateTitle)
    }

    func testMigratesVersionTwoCommonMediaSettingsToBothSites() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("user_settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let versionTwoJSON = """
        {
          "schema_version": 2,
          "selected_site": "automatic",
          "common": {
            "downloadPath": "/tmp/v2",
            "quality": "720p",
            "outputFormat": "mkv",
            "filenameTemplate": "仅标题(id)",
            "customTemplate": "%(id)s",
            "translateTitle": false,
            "embedThumbnail": false,
            "useProxy": true,
            "proxyURL": "http://127.0.0.1:7890"
          },
          "sites": {
            "pornhub": { "pageSelection": "2", "username": "user", "useCookies": false },
            "youtube": {
              "playlistSelection": "1-5",
              "channelScope": "Shorts",
              "subtitleMode": "人工字幕",
              "subtitleLanguages": "zh-Hans",
              "codecPreference": "H.264 兼容优先",
              "requestIntervalSeconds": 7,
              "useCookies": false
            }
          }
        }
        """
        try Data(versionTwoJSON.utf8).write(to: fileURL)

        let settings = SettingsStore(fileURL: fileURL).settings
        XCTAssertEqual(settings.schemaVersion, 5)
        XCTAssertEqual(settings.common.rateLimit, .unlimited)
        XCTAssertEqual(settings.common.concurrentFragments, 8)
        XCTAssertEqual(settings.sites.pornhub.media.filenameTemplate, .title)
        XCTAssertEqual(settings.sites.youtube.media.filenameTemplate, .title)
        XCTAssertFalse(settings.sites.pornhub.media.translateTitle)
        XCTAssertFalse(settings.sites.youtube.media.embedThumbnail)
        XCTAssertEqual(settings.sites.youtube.channelScope, .shorts)
        let persisted = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        )
        XCTAssertEqual(persisted["schema_version"] as? Int, 5)
    }

    func testSchemaFourAddsIndependentDouyinDefaultsWithoutLosingExistingSites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("settings.json")
        var existing = DownloadSettings.defaults
        existing.schemaVersion = 4
        existing.sites.pornhub.username = "kept"
        existing.sites.youtube.requestIntervalSeconds = 11
        existing.sites.x.useCookies = true
        existing.sites.tiktok.media.filenameTemplate = .title
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(existing)) as! [String: Any]
        var sites = object["sites"] as! [String: Any]
        sites.removeValue(forKey: "douyin")
        object["sites"] = sites
        try JSONSerialization.data(withJSONObject: object).write(to: file)

        let migrated = SettingsStore(fileURL: file).settings
        XCTAssertEqual(migrated.schemaVersion, 5)
        XCTAssertEqual(migrated.sites.pornhub.username, "kept")
        XCTAssertEqual(migrated.sites.youtube.requestIntervalSeconds, 11)
        XCTAssertTrue(migrated.sites.x.useCookies)
        XCTAssertEqual(migrated.sites.tiktok.media.filenameTemplate, .title)
        XCTAssertEqual(migrated.sites.douyin.media, .douyinDefaults)
        XCTAssertFalse(migrated.sites.douyin.useCookies)
    }
}
