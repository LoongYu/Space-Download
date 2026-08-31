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
}
