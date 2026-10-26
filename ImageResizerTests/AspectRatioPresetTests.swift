import XCTest
@testable import ImageResizer

final class AspectRatioPresetTests: XCTestCase {

    func testInvertStandardPhoto4to3() {
        guard let photo43 = AspectRatioPreset.all.first(where: { $0.ratioLabel == "4:3" }) else {
            XCTFail("4:3 preset not found")
            return
        }

        XCTAssertEqual(photo43.width, 1600)
        XCTAssertEqual(photo43.height, 1200)

        let inverted = photo43.inverted()
        XCTAssertEqual(inverted.ratioLabel, "3:4")
        XCTAssertEqual(inverted.width, 1200)
        XCTAssertEqual(inverted.height, 1600)

        // Inverting again restores original dimensions
        let doubleInverted = inverted.inverted()
        XCTAssertEqual(doubleInverted.width, 1600)
        XCTAssertEqual(doubleInverted.height, 1200)
    }

    func testInvertWidescreen16to9() {
        guard let wide169 = AspectRatioPreset.all.first(where: { $0.ratioLabel == "16:9" }) else {
            XCTFail("16:9 preset not found")
            return
        }

        let inverted = wide169.inverted()
        XCTAssertEqual(inverted.ratioLabel, "9:16")
        XCTAssertEqual(inverted.width, 1080)
        XCTAssertEqual(inverted.height, 1920)
    }

    func testInvertSquareRemainsSquare() {
        guard let square = AspectRatioPreset.all.first(where: { $0.ratioLabel == "1:1" }) else {
            XCTFail("1:1 preset not found")
            return
        }

        let inverted = square.inverted()
        XCTAssertEqual(inverted.ratioLabel, "1:1")
        XCTAssertEqual(inverted.width, 1080)
        XCTAssertEqual(inverted.height, 1080)
    }

    func testInvertPortrait4to5() {
        guard let portrait45 = AspectRatioPreset.all.first(where: { $0.ratioLabel == "4:5" }) else {
            XCTFail("4:5 preset not found")
            return
        }

        let inverted = portrait45.inverted()
        XCTAssertEqual(inverted.ratioLabel, "5:4")
        XCTAssertEqual(inverted.width, 1350)
        XCTAssertEqual(inverted.height, 1080)
    }
}
