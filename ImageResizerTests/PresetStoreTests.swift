import XCTest
@testable import ImageResizer

final class PresetStoreTests: XCTestCase {

    func testDefaultPresetsLoaded() {
        let store = PresetStore()
        XCTAssertGreaterThanOrEqual(store.presets.count, 4)
        XCTAssertTrue(store.presets.contains(where: { $0.name == "Small" }))
        XCTAssertTrue(store.presets.contains(where: { $0.name == "Medium" }))
        XCTAssertTrue(store.presets.contains(where: { $0.name == "Large" }))
    }

    func testAddAndRemoveCustomPreset() {
        let store = PresetStore()
        let initialCount = store.presets.count

        store.addPreset(name: "Social Banner", maxWidth: 1200, maxHeight: 630)
        XCTAssertEqual(store.presets.count, initialCount + 1)

        guard let added = store.presets.first(where: { $0.name == "Social Banner" }) else {
            XCTFail("Preset not found")
            return
        }

        XCTAssertEqual(added.maxWidth, 1200)
        XCTAssertEqual(added.maxHeight, 630)
        XCTAssertFalse(added.isBuiltIn)

        // Delete custom preset
        store.deletePreset(id: added.id)
        XCTAssertEqual(store.presets.count, initialCount)
    }

    func testCannotDeleteBuiltInPreset() {
        let store = PresetStore()
        let smallPreset = ResizePreset.small

        store.deletePreset(id: smallPreset.id)
        XCTAssertTrue(store.presets.contains(where: { $0.id == smallPreset.id }))
    }
}
