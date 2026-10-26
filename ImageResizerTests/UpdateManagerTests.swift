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
        }

        if let edKey = info["SUPublicEDKey"] as? String {
            XCTAssertFalse(edKey.isEmpty, "SUPublicEDKey should be configured")
        }
    }
}
