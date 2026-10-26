import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

public final class ImageFileService: @unchecked Sendable {
    public static let shared = ImageFileService()

    public static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "gif"
    ]

    public static let supportedContentTypes: [UTType] = [
        .image,
        .jpeg,
        .png,
        .heic,
        .heif,
        .webP,
        .tiff,
        .bmp,
        .gif
    ]

    public init() {}

    /// Shows native macOS Open Panel to select image files
    @MainActor
    public func selectFilesWithOpenPanel(allowsMultiple: Bool = true) -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Select Images to Resize"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = ImageFileService.supportedContentTypes

        let response = panel.runModal()
        guard response == .OK else { return [] }

        return collectImageURLs(from: panel.urls)
    }

    /// Recursively collects supported image URLs from files or directories
    public func collectImageURLs(from urls: [URL]) -> [URL] {
        var results: [URL] = []
        let fileManager = FileManager.default

        for url in urls {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    if let enumerator = fileManager.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) {
                        for case let fileURL as URL in enumerator {
                            if isSupportedImage(fileURL) {
                                results.append(fileURL)
                            }
                        }
                    }
                } else if isSupportedImage(url) {
                    results.append(url)
                }
            }
        }

        return results
    }

    public func isSupportedImage(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ImageFileService.supportedExtensions.contains(ext) {
            return true
        }
        if let utType = UTType(filenameExtension: ext),
           utType.conforms(to: .image) {
            return true
        }
        return false
    }

    /// Loads lightweight metadata for an ImageItem without reading the full pixel buffer into memory.
    public func createImageItem(from url: URL) -> ImageItem? {
        do {
            let (dimensions, utType, formatName) = try ImageResizeEngine.readImageProperties(at: url)
            let fileValues = try? url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(fileValues?.fileSize ?? 0)

            return ImageItem(
                url: url,
                filename: url.lastPathComponent,
                fileSize: fileSize,
                originalDimensions: dimensions,
                utiString: utType?.identifier,
                formatName: formatName
            )
        } catch {
            print("Failed to read metadata for \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    /// Generates a fast, low-memory thumbnail for the queue list
    public func generateThumbnail(for url: URL, maxPixelSize: Int = 128) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
            return nil
        }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
    }
}
