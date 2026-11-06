import XCTest
@testable import ImageResizer

final class OutputManagerTests: XCTestCase {
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

    func testSubfolderDestinationCreation() throws {
        let dummySource = tempDirectory.appendingPathComponent("sample.jpg")
        try Data("test".utf8).write(to: dummySource)

        var config = ResizeConfiguration()
        config.destinationMode = .subfolder
        config.subfolderName = "CustomResized"
        config.filenameSuffix = "-resized"

        let resolvedURL = try OutputManager.shared.resolveDestinationURL(
            for: dummySource,
            configuration: config
        )

        XCTAssertTrue(fileManager.fileExists(atPath: resolvedURL.deletingLastPathComponent().path))
        XCTAssertEqual(resolvedURL.lastPathComponent, "sample-resized.jpg")
        XCTAssertEqual(resolvedURL.deletingLastPathComponent().lastPathComponent, "CustomResized")
    }

    func testAppendPresetNameToFilename() throws {
        let dummySource = tempDirectory.appendingPathComponent("vacation.png")
        try Data("test".utf8).write(to: dummySource)

        var config = ResizeConfiguration()
        config.destinationMode = .sameFolder
        config.filenameSuffix = "-small"
        config.appendPresetNameToFilename = true

        let resolvedURL = try OutputManager.shared.resolveDestinationURL(
            for: dummySource,
            configuration: config,
            presetName: "Web Thumbnail"
        )

        XCTAssertEqual(resolvedURL.lastPathComponent, "vacation-small_Web_Thumbnail.png")
    }

    func testFormatExtensionConversion() throws {
        let dummySource = tempDirectory.appendingPathComponent("image.png")
        try Data("test".utf8).write(to: dummySource)

        var config = ResizeConfiguration()
        config.destinationMode = .sameFolder
        config.outputFormat = .jpeg
        config.filenameSuffix = "-compressed"

        let resolvedURL = try OutputManager.shared.resolveDestinationURL(
            for: dummySource,
            configuration: config
        )

        XCTAssertEqual(resolvedURL.lastPathComponent, "image-compressed.jpg")
    }

    func testFilenameCollisionAutoNumbering() throws {
        let dummySource = tempDirectory.appendingPathComponent("photo.jpg")
        try Data("test".utf8).write(to: dummySource)

        var config = ResizeConfiguration()
        config.destinationMode = .sameFolder
        config.filenameSuffix = "-resized"
        config.collisionHandling = .renameWithNumber

        // First resolution: photo-resized.jpg
        let firstURL = try OutputManager.shared.resolveDestinationURL(for: dummySource, configuration: config)
        XCTAssertEqual(firstURL.lastPathComponent, "photo-resized.jpg")
        try Data("test".utf8).write(to: firstURL)

        // Second resolution: should become photo-resized (1).jpg
        let secondURL = try OutputManager.shared.resolveDestinationURL(for: dummySource, configuration: config)
        XCTAssertEqual(secondURL.lastPathComponent, "photo-resized (1).jpg")
        try Data("test".utf8).write(to: secondURL)

        // Third resolution: should become photo-resized (2).jpg
        let thirdURL = try OutputManager.shared.resolveDestinationURL(for: dummySource, configuration: config)
        XCTAssertEqual(thirdURL.lastPathComponent, "photo-resized (2).jpg")
    }

    func testNeverOverwritesOriginalSourceFile() throws {
        let dummySource = tempDirectory.appendingPathComponent("photo.jpg")
        try Data("test".utf8).write(to: dummySource)

        var config = ResizeConfiguration()
        config.destinationMode = .sameFolder
        config.filenameSuffix = "" // No suffix!
        config.collisionHandling = .overwrite // User set overwrite!

        let resolvedURL = try OutputManager.shared.resolveDestinationURL(for: dummySource, configuration: config)

        // Must NOT match source URL
        XCTAssertNotEqual(resolvedURL.path, dummySource.path)
    }
}
