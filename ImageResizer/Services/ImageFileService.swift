import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers
import AVFoundation

public final class ImageFileService: @unchecked Sendable {
    public static let shared = ImageFileService()

    public static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "gif"
    ]
    public static let supportedVideoExtensions: Set<String> = [
        "mov", "qt", "mp4", "m4v", "3gp", "3g2", "avi", "mpg", "mpeg", "m2v",
        "mts", "m2ts", "ts", "dv", "vob", "mxf", "webm", "mkv"
    ]

    public static var supportedVideoContentTypes: [UTType] {
        var advertised: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie]
        if #available(macOS 26.0, *) {
            advertised.append(contentsOf: AVURLAsset.audiovisualContentTypes.filter { $0.conforms(to: .movie) })
        }
        let extensionTypes = supportedVideoExtensions.compactMap { UTType(filenameExtension: $0) }
        let mxfType = UTType(importedAs: "org.smpte.mxf", conformingTo: .movie)
        var seen = Set<String>()
        return (advertised + extensionTypes + [mxfType])
            .filter { seen.insert($0.identifier).inserted }
    }

    public static let supportedContentTypes: [UTType] = [
        .image,
        .jpeg,
        .png,
        .heic,
        .heif,
        .webP,
        .tiff,
        .bmp,
        .gif,
        .movie, .mpeg4Movie, .quickTimeMovie
    ]

    public init() {}

    /// Shows native macOS Open Panel to select image files
    @MainActor
    public func selectFilesWithOpenPanel(allowsMultiple: Bool = true, kind: MediaKind? = nil) -> [URL] {
        let panel = NSOpenPanel()
        panel.title = kind == .video ? "Select Videos" : "Select Images"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = kind == .video ? ImageFileService.supportedVideoContentTypes : ImageFileService.supportedContentTypes

        let response = panel.runModal()
        guard response == .OK else { return [] }

        return panel.urls.flatMap { url in
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return collectImageURLs(from: [url]).filter { kind == nil || (kind == .image ? isSupportedImage($0) : isSupportedVideo($0)) }
            }
            return kind == nil || (kind == .image ? isSupportedImage(url) : isSupportedVideo(url)) ? [url] : []
        }
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
                            if isSupportedMedia(fileURL) {
                                results.append(fileURL)
                            }
                        }
                    }
                } else if isSupportedMedia(url) {
                    results.append(url)
                }
            }
        }

        return results
    }

    public func isSupportedMedia(_ url: URL) -> Bool {
        isSupportedImage(url) || ImageFileService.supportedVideoExtensions.contains(url.pathExtension.lowercased())
    }

    public func createMediaItem(from url: URL, kind: MediaKind? = nil) -> ImageItem? {
        if let kind {
            guard (kind == .image && isSupportedImage(url)) || (kind == .video && isSupportedVideo(url)) else { return nil }
        }
        if isSupportedImage(url) { return createImageItem(from: url) }
        guard ImageFileService.supportedVideoExtensions.contains(url.pathExtension.lowercased()) else { return nil }
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        let dimensions = ImageDimensions(width: Int(abs(size.width)), height: Int(abs(size.height)))
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let thumbnail: NSImage?
        if let cg = try? AVAssetImageGenerator(asset: asset).copyCGImage(at: .zero, actualTime: nil) {
            thumbnail = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        } else { thumbnail = nil }
        return ImageItem(url: url, filename: url.lastPathComponent, fileSize: Int64(values?.fileSize ?? 0), originalDimensions: dimensions, formatName: "Video", thumbnail: thumbnail, mediaKind: .video, sourceVideoBitrate: Int(track.estimatedDataRate))
    }

    public func createVideoItem(from url: URL) async -> ImageItem? {
        guard isSupportedVideo(url) else { return nil }
        let asset = AVURLAsset(url: url)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else { return nil }
            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let displaySize = naturalSize.applying(transform)
            let bitrate = try? await track.load(.estimatedDataRate)
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            let thumbnail: NSImage?
            if let cgImage = try? AVAssetImageGenerator(asset: asset).copyCGImage(at: .zero, actualTime: nil) {
                thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            } else {
                thumbnail = nil
            }
            return ImageItem(
                url: url,
                filename: url.lastPathComponent,
                fileSize: Int64(values?.fileSize ?? 0),
                originalDimensions: ImageDimensions(width: Int(abs(displaySize.width)), height: Int(abs(displaySize.height))),
                formatName: "Video",
                thumbnail: thumbnail,
                mediaKind: .video,
                sourceVideoBitrate: bitrate.map(Int.init)
            )
        } catch {
            print("Failed to read video metadata for \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    public func isSupportedVideo(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ImageFileService.supportedVideoExtensions.contains(ext) { return true }
        guard let contentType = UTType(filenameExtension: ext) else { return false }
        return contentType.conforms(to: .movie)
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
