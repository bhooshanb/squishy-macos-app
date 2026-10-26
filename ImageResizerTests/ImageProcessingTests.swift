import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ImageResizer

final class ImageProcessingTests: XCTestCase {
    var tempDirectory: URL!
    let fileManager = FileManager.default

    override func setUp() {
        super.setUp()
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? fileManager.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Actual Image Resize Tests

    func testResizePNGWithTransparency() throws {
        // Create 800 x 600 transparent PNG with a colored circle
        let sourceURL = tempDirectory.appendingPathComponent("circle.png")
        let destinationURL = tempDirectory.appendingPathComponent("circle-resized.png")

        try createTestImage(url: sourceURL, width: 800, height: 600, hasAlpha: true, utType: UTType.png)

        let target = ImageDimensions(width: 400, height: 300)
        try ImageResizeEngine.shared.resizeImage(
            from: sourceURL,
            to: destinationURL,
            targetDimensions: target,
            outputFormat: .png,
            quality: 1.0
        )

        XCTAssertTrue(fileManager.fileExists(atPath: destinationURL.path))
        let (outputDim, _, _) = try ImageResizeEngine.readImageProperties(at: destinationURL)
        XCTAssertEqual(outputDim.width, 400)
        XCTAssertEqual(outputDim.height, 300)
    }

    func testResizeJPEGHighQuality() throws {
        // Create 1200 x 900 JPEG
        let sourceURL = tempDirectory.appendingPathComponent("scenery.jpg")
        let destinationURL = tempDirectory.appendingPathComponent("scenery-small.jpg")

        try createTestImage(url: sourceURL, width: 1200, height: 900, hasAlpha: false, utType: UTType.jpeg)

        let target = ImageDimensions(width: 600, height: 450)
        try ImageResizeEngine.shared.resizeImage(
            from: sourceURL,
            to: destinationURL,
            targetDimensions: target,
            outputFormat: .jpeg,
            quality: 0.85
        )

        XCTAssertTrue(fileManager.fileExists(atPath: destinationURL.path))
        let (outputDim, utType, _) = try ImageResizeEngine.readImageProperties(at: destinationURL)
        XCTAssertEqual(outputDim.width, 600)
        XCTAssertEqual(outputDim.height, 450)
        XCTAssertEqual(utType, .jpeg)
    }

    func testResizeTIFFFormat() throws {
        let sourceURL = tempDirectory.appendingPathComponent("document.tiff")
        let destinationURL = tempDirectory.appendingPathComponent("document-resized.tiff")

        try createTestImage(url: sourceURL, width: 1000, height: 500, hasAlpha: false, utType: UTType.tiff)

        let target = ImageDimensions(width: 500, height: 250)
        try ImageResizeEngine.shared.resizeImage(
            from: sourceURL,
            to: destinationURL,
            targetDimensions: target,
            outputFormat: .tiff,
            quality: 1.0
        )

        XCTAssertTrue(fileManager.fileExists(atPath: destinationURL.path))
        let (outputDim, utType, _) = try ImageResizeEngine.readImageProperties(at: destinationURL)
        XCTAssertEqual(outputDim.width, 500)
        XCTAssertEqual(outputDim.height, 250)
        XCTAssertEqual(utType, .tiff)
    }

    func testResizeHEICFormat() throws {
        let sourceURL = tempDirectory.appendingPathComponent("photo.heic")
        let destinationURL = tempDirectory.appendingPathComponent("photo-resized.heic")

        try createTestImage(url: sourceURL, width: 1200, height: 800, hasAlpha: false, utType: UTType.heic)

        let target = ImageDimensions(width: 600, height: 400)
        try ImageResizeEngine.shared.resizeImage(
            from: sourceURL,
            to: destinationURL,
            targetDimensions: target,
            outputFormat: .heic,
            quality: 0.8
        )

        XCTAssertTrue(fileManager.fileExists(atPath: destinationURL.path))
        let (outputDim, utType, _) = try ImageResizeEngine.readImageProperties(at: destinationURL)
        XCTAssertEqual(outputDim.width, 600)
        XCTAssertEqual(outputDim.height, 400)
        XCTAssertEqual(utType, .heic)
    }

    func testUnsupportedFormatThrowsCannotCreateDestination() throws {
        let sourceURL = tempDirectory.appendingPathComponent("graphic.png")
        let destinationURL = tempDirectory.appendingPathComponent("graphic.webp")

        try createTestImage(url: sourceURL, width: 1000, height: 500, hasAlpha: false, utType: UTType.png)

        let supportedTypes = CGImageDestinationCopyTypeIdentifiers() as! [String]
        let webpSupported = supportedTypes.contains(UTType.webP.identifier)

        let target = ImageDimensions(width: 500, height: 250)
        if !webpSupported {
            // macOS without WebP encoder throws cannotCreateDestination
            XCTAssertThrowsError(try ImageResizeEngine.shared.resizeImage(
                from: sourceURL,
                to: destinationURL,
                targetDimensions: target,
                outputFormat: .webp,
                quality: 0.8
            )) { error in
                guard let resizeError = error as? ImageResizeError else {
                    XCTFail("Expected ImageResizeError")
                    return
                }
                XCTAssertEqual(resizeError, .cannotCreateDestination(destinationURL))
            }
        } else {
            try ImageResizeEngine.shared.resizeImage(
                from: sourceURL,
                to: destinationURL,
                targetDimensions: target,
                outputFormat: .webp,
                quality: 0.8
            )
            XCTAssertTrue(fileManager.fileExists(atPath: destinationURL.path))
        }
    }

    func testCorruptedFileThrowsErrorGracefully() {
        let corruptedURL = tempDirectory.appendingPathComponent("broken.jpg")
        try? Data("Not a real JPEG image file".utf8).write(to: corruptedURL)

        XCTAssertThrowsError(try ImageResizeEngine.readImageProperties(at: corruptedURL)) { error in
            guard let resizeError = error as? ImageResizeError else {
                XCTFail("Expected ImageResizeError")
                return
            }
            XCTAssertEqual(resizeError, .unsupportedOrCorruptedFormat(corruptedURL))
        }
    }

    // MARK: - Helpers

    private func createTestImage(url: URL, width: Int, height: Int, hasAlpha: Bool, utType: UTType) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = hasAlpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw ImageResizeError.invalidDimensions("Cannot create context")
        }

        // Draw sample content
        if hasAlpha {
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.8))
            context.fillEllipse(in: CGRect(x: 20, y: 20, width: width - 40, height: height - 40))
        } else {
            context.setFillColor(CGColor(red: 0.9, green: 0.4, blue: 0.2, alpha: 1.0))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        guard let image = context.makeImage() else {
            throw ImageResizeError.invalidDimensions("Cannot create CGImage")
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, utType.identifier as CFString, 1, nil) else {
            throw ImageResizeError.cannotCreateDestination(url)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageResizeError.failedToFinalizeImage(url)
        }
    }
}
