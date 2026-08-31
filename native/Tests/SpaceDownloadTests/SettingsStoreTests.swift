import Foundation
import XCTest
@testable import SpaceDownload

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testTitleOnlyTemplateIsFirstAndPersistsForEverySite() throws {
        XCTAssertEqual(FilenameTemplate.allCases.first, .titleOnly)
        XCTAssertEqual(FilenameTemplate.titleOnly.rule, "%(title)s")
        XCTAssertEqual(FilenameTemplate.title.rule, "%(title)s(%(id)s)")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = directory.appendingPathComponent("settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SettingsStore(fileURL: file)
        store.settings.sites.pornhub.media.filenameTemplate = .titleOnly
        store.settings.sites.youtube.media.filenameTemplate = .titleOnly
        store.settings.sites.x.media.filenameTemplate = .titleOnly
        store.settings.sites.tiktok.media.filenameTemplate = .titleOnly
        store.settings.sites.douyin.media.filenameTemplate = .titleOnly
        store.settings.sites.instagram.media.filenameTemplate = .titleOnly
        store.settings.sites.telegram.media.filenameTemplate = .titleOnly

        let reloaded = SettingsStore(fileURL: file).settings
        XCTAssertEqual(reloaded.sites.pornhub.media.filenameTemplate, .titleOnly)
        XCTAssertEqual(reloaded.sites.youtube.media.filenameTemplate, .titleOnly)
        XCTAssertEqual(reloaded.sites.x.media.filenameTemplate, .titleOnly)
        XCTAssertEqual(reloaded.sites.tiktok.media.filenameTemplate, .titleOnly)
        XCTAssertEqual(reloaded.sites.douyin.media.filenameTemplate, .titleOnly)
        XCTAssertEqual(reloaded.sites.instagram.media.filenameTemplate, .titleOnly)
        XCTAssertEqual(reloaded.sites.telegram.media.filenameTemplate, .titleOnly)
    }

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
        XCTAssertEqual(migrated.schemaVersion, 7)
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
        XCTAssertEqual(reloaded.settings.schemaVersion, 7)
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
        XCTAssertEqual(settings.schemaVersion, 7)
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
        XCTAssertEqual(persisted["schema_version"] as? Int, 7)
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
        XCTAssertEqual(migrated.schemaVersion, 7)
        XCTAssertEqual(migrated.sites.pornhub.username, "kept")
        XCTAssertEqual(migrated.sites.youtube.requestIntervalSeconds, 11)
        XCTAssertTrue(migrated.sites.x.useCookies)
        XCTAssertEqual(migrated.sites.tiktok.media.filenameTemplate, .title)
        XCTAssertEqual(migrated.sites.douyin.media, .douyinDefaults)
        XCTAssertFalse(migrated.sites.douyin.useCookies)
    }

    func testSchemaFiveAddsInstagramWithoutLosingExistingSiteSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("settings.json")
        var existing = DownloadSettings.defaults
        existing.schemaVersion = 5
        existing.sites.pornhub.username = "kept"
        existing.sites.youtube.requestIntervalSeconds = 12
        existing.sites.x.useCookies = true
        existing.sites.tiktok.media.translateTitle = true
        existing.sites.douyin.media.embedThumbnail = false
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(existing)) as! [String: Any]
        var sites = object["sites"] as! [String: Any]
        sites.removeValue(forKey: "instagram")
        object["sites"] = sites
        try JSONSerialization.data(withJSONObject: object).write(to: file)

        let migrated = SettingsStore(fileURL: file).settings
        XCTAssertEqual(migrated.schemaVersion, 7)
        XCTAssertEqual(migrated.sites.pornhub.username, "kept")
        XCTAssertEqual(migrated.sites.youtube.requestIntervalSeconds, 12)
        XCTAssertTrue(migrated.sites.x.useCookies)
        XCTAssertTrue(migrated.sites.tiktok.media.translateTitle)
        XCTAssertFalse(migrated.sites.douyin.media.embedThumbnail)
        XCTAssertEqual(migrated.sites.instagram.media, .instagramDefaults)
        XCTAssertFalse(migrated.sites.instagram.useCookies)
    }

    func testPersistsIndependentInstagramSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = directory.appendingPathComponent("settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SettingsStore(fileURL: file)
        store.settings.selectedSite = .instagram
        store.settings.sites.instagram.useCookies = true
        store.settings.sites.instagram.media.filenameTemplate = .title

        let reloaded = SettingsStore(fileURL: file).settings
        XCTAssertEqual(reloaded.selectedSite, .instagram)
        XCTAssertTrue(reloaded.sites.instagram.useCookies)
        XCTAssertEqual(reloaded.sites.instagram.media.filenameTemplate, .title)
        XCTAssertEqual(reloaded.sites.x.media, .defaults)
    }

    func testSchemaSixAddsTelegramWithoutLosingExistingSiteSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = directory.appendingPathComponent("settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var existing = DownloadSettings.defaults
        existing.schemaVersion = 6
        existing.sites.pornhub.username = "kept"
        existing.sites.youtube.requestIntervalSeconds = 13
        existing.sites.instagram.useCookies = true
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(existing)) as! [String: Any]
        var sites = object["sites"] as! [String: Any]
        sites.removeValue(forKey: "telegram")
        object["sites"] = sites
        try JSONSerialization.data(withJSONObject: object).write(to: file)

        let migrated = SettingsStore(fileURL: file).settings
        XCTAssertEqual(migrated.schemaVersion, 7)
        XCTAssertEqual(migrated.sites.pornhub.username, "kept")
        XCTAssertEqual(migrated.sites.youtube.requestIntervalSeconds, 13)
        XCTAssertTrue(migrated.sites.instagram.useCookies)
        XCTAssertEqual(migrated.sites.telegram.media, .telegramDefaults)
    }

    func testPersistsIndependentTelegramSettingsWithoutCookieField() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = directory.appendingPathComponent("settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SettingsStore(fileURL: file)
        store.settings.selectedSite = .telegram
        store.settings.sites.telegram.media.filenameTemplate = .dateTitle
        store.settings.sites.telegram.media.translateTitle = true

        let reloaded = SettingsStore(fileURL: file).settings
        XCTAssertEqual(reloaded.selectedSite, .telegram)
        XCTAssertEqual(reloaded.sites.telegram.media.filenameTemplate, .dateTitle)
        XCTAssertTrue(reloaded.sites.telegram.media.translateTitle)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        let sites = object["sites"] as! [String: Any]
        let telegram = sites["telegram"] as! [String: Any]
        XCTAssertNil(telegram["useCookies"])
        XCTAssertNil(telegram["use_cookies"])
    }
}
