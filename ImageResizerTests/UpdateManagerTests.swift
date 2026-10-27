import XCTest
@testable import ImageResizer

final class UpdateManagerTests: XCTestCase {

    @MainActor
    func testUpdateManagerSingletonExists() {
        let manager = UpdateManager.shared
        XCTAssertNotNil(manager, "UpdateManager singleton should be accessible")
    }

    @MainActor
    func testUpdateManagerProperties() {
        let manager = UpdateManager.shared
        // In test environment, starting updater is bypassed so it should not crash
        XCTAssertFalse(manager.canCheckForUpdates, "canCheckForUpdates is false in test runner")
        
        // Ensure property accessors are safe
        _ = manager.automaticallyChecksForUpdates
        _ = manager.automaticallyDownloadsUpdates
        _ = manager.lastUpdateCheckDate
        _ = manager.feedURL
        XCTAssertTrue(manager.activeFeedURLString.contains("appcast.xml"), "Feed URL should reference appcast.xml")
        XCTAssertTrue(manager.activeFeedURLString.contains("bhooshanb/squishy-macos-app"), "Feed URL should reference the git repo")
    }

    func testBundleContainsSparkleConfiguration() {
        guard let info = Bundle.main.infoDictionary else {
            // If running inside test bundle, check host bundle
            let hostBundle = Bundle(for: UpdateManagerTests.self)
            XCTAssertNotNil(hostBundle)
            return
        }

        if let feedURLString = info["SUFeedURL"] as? String {
            XCTAssertTrue(feedURLString.hasPrefix("https://"), "SUFeedURL should be secure https URL")
            XCTAssertTrue(feedURLString.contains("bhooshanb/squishy-macos-app"), "SUFeedURL should point to bhooshanb/squishy-macos-app repository")
        }

        if let edKey = info["SUPublicEDKey"] as? String {
            XCTAssertFalse(edKey.isEmpty, "SUPublicEDKey should be configured")
        }

        if let brandName = info["CFBundleName"] as? String {
            XCTAssertEqual(brandName, "Squishy", "Brand name should be Squishy")
        }

        if let supportEmail = info["SilverstoneSupportEmail"] as? String {
            XCTAssertEqual(supportEmail, "info@silverstonelabs.in")
        }

        if let website = info["SilverstoneWebsite"] as? String {
            XCTAssertEqual(website, "https://apps.silverstonelabs.in")
        }
    }
}
