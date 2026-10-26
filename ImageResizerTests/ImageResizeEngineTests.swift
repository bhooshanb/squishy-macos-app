import XCTest
@testable import ImageResizer

final class ImageResizeEngineTests: XCTestCase {

    // MARK: - Landscape, Portrait, and Square Presets

    func testLandscapeImageMediumPreset() {
        // 4000 x 3000 (4:3) with Medium preset (1366 x 768)
        let original = ImageDimensions(width: 4000, height: 3000)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .preset,
            preset: ResizePreset.medium,
            allowUpscaling: false
        )

        // Expected: 1024 x 768 (strictly preserves 4:3 aspect ratio, fits inside 1366 x 768)
        XCTAssertEqual(result.width, 1024)
        XCTAssertEqual(result.height, 768)
        XCTAssertLessThanOrEqual(result.width, 1366)
        XCTAssertLessThanOrEqual(result.height, 768)
        XCTAssertEqual(result.aspectRatio, original.aspectRatio, accuracy: 0.01)
    }

    func testPortraitImageMediumPreset() {
        // 3000 x 4000 (3:4) with Medium preset (1366 x 768)
        let original = ImageDimensions(width: 3000, height: 4000)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .preset,
            preset: ResizePreset.medium,
            allowUpscaling: false
        )

        // Expected: height capped at 768, width = 768 * (3/4) = 576
        XCTAssertEqual(result.width, 576)
        XCTAssertEqual(result.height, 768)
        XCTAssertLessThanOrEqual(result.width, 1366)
        XCTAssertLessThanOrEqual(result.height, 768)
        XCTAssertEqual(result.aspectRatio, original.aspectRatio, accuracy: 0.01)
    }

    func testSquareImageSmallPreset() {
        // 2000 x 2000 (1:1) with Small preset (854 x 480)
        let original = ImageDimensions(width: 2000, height: 2000)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .preset,
            preset: ResizePreset.small,
            allowUpscaling: false
        )

        // Bounded by height 480 -> 480 x 480
        XCTAssertEqual(result.width, 480)
        XCTAssertEqual(result.height, 480)
        XCTAssertLessThanOrEqual(result.width, 854)
        XCTAssertLessThanOrEqual(result.height, 480)
        XCTAssertEqual(result.aspectRatio, 1.0)
    }

    // MARK: - Very Wide (Panoramic) and Very Tall (Banner)

    func testVeryWidePanorama() {
        // 10000 x 1000 (10:1) with Large preset (1920 x 1080)
        let original = ImageDimensions(width: 10000, height: 1000)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .preset,
            preset: ResizePreset.large,
            allowUpscaling: false
        )

        // Bounded by width 1920 -> 1920 x 192
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 192)
        XCTAssertLessThanOrEqual(result.width, 1920)
        XCTAssertLessThanOrEqual(result.height, 1080)
        XCTAssertEqual(result.aspectRatio, original.aspectRatio, accuracy: 0.02)
    }

    func testVeryTallImage() {
        // 1000 x 10000 (1:10) with Large preset (1920 x 1080)
        let original = ImageDimensions(width: 1000, height: 10000)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .preset,
            preset: ResizePreset.large,
            allowUpscaling: false
        )

        // Bounded by height 1080 -> 108 x 1080
        XCTAssertEqual(result.width, 108)
        XCTAssertEqual(result.height, 1080)
        XCTAssertLessThanOrEqual(result.width, 1920)
        XCTAssertLessThanOrEqual(result.height, 1080)
        XCTAssertEqual(result.aspectRatio, original.aspectRatio, accuracy: 0.02)
    }

    // MARK: - Images Smaller than Preset & Upscaling Behavior

    func testImageSmallerThanPresetWithoutUpscaling() {
        // 600 x 400 with Large preset (1920 x 1080), allowUpscaling = false
        let original = ImageDimensions(width: 600, height: 400)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .preset,
            preset: ResizePreset.large,
            allowUpscaling: false
        )

        // Accidental upscaling must be prevented!
        XCTAssertEqual(result.width, 600)
        XCTAssertEqual(result.height, 400)
    }

    func testImageSmallerThanPresetWithUpscalingEnabled() {
        // 600 x 400 with Large preset (1920 x 1080), allowUpscaling = true
        let original = ImageDimensions(width: 600, height: 400)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .preset,
            preset: ResizePreset.large,
            allowUpscaling: true
        )

        // Scale factors: 1920/600 = 3.2, 1080/400 = 2.7 -> min scale = 2.7
        // 600 * 2.7 = 1620, 400 * 2.7 = 1080
        XCTAssertEqual(result.width, 1620)
        XCTAssertEqual(result.height, 1080)
        XCTAssertLessThanOrEqual(result.width, 1920)
        XCTAssertLessThanOrEqual(result.height, 1080)
    }

    // MARK: - Custom Width and Height (Fit Mode)

    func testCustomFitBoundingBox() {
        let original = ImageDimensions(width: 1920, height: 1080)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .fit,
            targetWidth: 800,
            targetHeight: 800,
            allowUpscaling: false
        )

        // 16:9 inside 800x800 -> 800 x 450
        XCTAssertEqual(result.width, 800)
        XCTAssertEqual(result.height, 450)
        XCTAssertLessThanOrEqual(result.width, 800)
        XCTAssertLessThanOrEqual(result.height, 800)
    }

    // MARK: - Width-only and Height-only Resizing

    func testWidthOnlyResizing() {
        let original = ImageDimensions(width: 2000, height: 1000) // 2:1
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .widthOnly,
            targetWidth: 500,
            allowUpscaling: false
        )

        XCTAssertEqual(result.width, 500)
        XCTAssertEqual(result.height, 250)
    }

    func testHeightOnlyResizing() {
        let original = ImageDimensions(width: 2000, height: 1000) // 2:1
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .heightOnly,
            targetHeight: 300,
            allowUpscaling: false
        )

        XCTAssertEqual(result.width, 600)
        XCTAssertEqual(result.height, 300)
    }

    func testWidthOnlyWithoutUpscalingPreventsEnlarging() {
        let original = ImageDimensions(width: 500, height: 250)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .widthOnly,
            targetWidth: 1000,
            allowUpscaling: false
        )

        // Should not enlarge
        XCTAssertEqual(result.width, 500)
        XCTAssertEqual(result.height, 250)
    }

    // MARK: - Percentage Scaling

    func testPercentageScaling50() {
        let original = ImageDimensions(width: 1200, height: 800)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .percentage,
            percentage: 50.0,
            allowUpscaling: false
        )

        XCTAssertEqual(result.width, 600)
        XCTAssertEqual(result.height, 400)
    }

    func testPercentageScaling150WithoutUpscaling() {
        let original = ImageDimensions(width: 1200, height: 800)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .percentage,
            percentage: 150.0,
            allowUpscaling: false
        )

        // Upscaling disabled -> stays original
        XCTAssertEqual(result.width, 1200)
        XCTAssertEqual(result.height, 800)
    }

    func testPercentageScaling150WithUpscaling() {
        let original = ImageDimensions(width: 1200, height: 800)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .percentage,
            percentage: 150.0,
            allowUpscaling: true
        )

        XCTAssertEqual(result.width, 1800)
        XCTAssertEqual(result.height, 1200)
    }

    // MARK: - Integer Rounding and Edge Cases

    func testOddDimensionsRounding() {
        // 999 x 667 (approx 1.49775) scaled to 50%
        let original = ImageDimensions(width: 999, height: 667)
        let result = ImageResizeEngine.calculateDimensions(
            original: original,
            mode: .percentage,
            percentage: 50.0,
            allowUpscaling: false
        )

        // 999 * 0.5 = 499.5 -> 500; 667 * 0.5 = 333.5 -> 334
        XCTAssertEqual(result.width, 500)
        XCTAssertEqual(result.height, 334)
    }

    func testZeroOrInvalidDimensions() {
        let zero = ImageDimensions(width: 0, height: 0)
        let result = ImageResizeEngine.calculateDimensions(
            original: zero,
            mode: .preset,
            preset: ResizePreset.medium,
            allowUpscaling: false
        )

        XCTAssertEqual(result.width, 0)
        XCTAssertEqual(result.height, 0)
    }

    func test1x1PixelImage() {
        let onePixel = ImageDimensions(width: 1, height: 1)
        let result = ImageResizeEngine.calculateDimensions(
            original: onePixel,
            mode: .preset,
            preset: ResizePreset.small,
            allowUpscaling: false
        )

        XCTAssertEqual(result.width, 1)
        XCTAssertEqual(result.height, 1)
    }

    // MARK: - Mode Transition & Consistency

    func testTransitionPresetToFitKeepsConsistentDimensions() {
        var config = ResizeConfiguration(mode: .preset, selectedPresetId: ResizePreset.small.id)
        let sample = ImageDimensions(width: 4000, height: 3000) // 4:3

        // Under small preset (854 x 480), 4:3 image becomes 640 x 480
        ImageResizeEngine.adaptConfigurationOnModeChange(
            configuration: &config,
            from: .preset,
            to: .fit,
            preset: ResizePreset.small,
            availablePresets: ResizePreset.defaultPresets,
            sampleOriginal: sample
        )

        XCTAssertEqual(config.customWidth, 640)
        XCTAssertEqual(config.customHeight, 480)
    }

    func testTransitionWidthToHeightDerivesProportionalHeight() {
        var config = ResizeConfiguration(mode: .widthOnly, customWidth: 1000)
        let sample = ImageDimensions(width: 2000, height: 1000) // 2:1

        // When width is 1000, derived height is 500
        ImageResizeEngine.adaptConfigurationOnModeChange(
            configuration: &config,
            from: .widthOnly,
            to: .heightOnly,
            preset: nil,
            availablePresets: ResizePreset.defaultPresets,
            sampleOriginal: sample
        )

        XCTAssertEqual(config.customHeight, 500)
    }

    func testTransitionPercentageToFitMatchesExactScaledDimensions() {
        var config = ResizeConfiguration(mode: .percentage, percentage: 25.0)
        let sample = ImageDimensions(width: 4000, height: 2000) // 2:1

        ImageResizeEngine.adaptConfigurationOnModeChange(
            configuration: &config,
            from: .percentage,
            to: .fit,
            preset: nil,
            availablePresets: ResizePreset.defaultPresets,
            sampleOriginal: sample
        )

        // 25% of 4000 x 2000 is 1000 x 500
        XCTAssertEqual(config.customWidth, 1000)
        XCTAssertEqual(config.customHeight, 500)
    }

    func testTransitionToPercentageDerivesAccurateScaleRatio() {
        var config = ResizeConfiguration(mode: .widthOnly, customWidth: 2000)
        let sample = ImageDimensions(width: 4000, height: 3000)

        ImageResizeEngine.adaptConfigurationOnModeChange(
            configuration: &config,
            from: .widthOnly,
            to: .percentage,
            preset: nil,
            availablePresets: ResizePreset.defaultPresets,
            sampleOriginal: sample
        )

        // 2000 / 4000 = 50%
        XCTAssertEqual(config.percentage, 50.0)
    }
}
