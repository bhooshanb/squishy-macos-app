import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ImageResizeError: LocalizedError, Equatable {
    case fileNotFound(URL)
    case unsupportedOrCorruptedFormat(URL)
    case invalidDimensions(String)
    case cannotCreateDestination(URL)
    case failedToFinalizeImage(URL)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .unsupportedOrCorruptedFormat(let url):
            return "Unsupported or corrupted image file: \(url.lastPathComponent)"
        case .invalidDimensions(let msg):
            return "Invalid dimensions: \(msg)"
        case .cannotCreateDestination(let url):
            return "Cannot create output file at: \(url.path)"
        case .failedToFinalizeImage(let url):
            return "Failed to encode and save image to: \(url.lastPathComponent)"
        case .cancelled:
            return "The resize operation was cancelled."
        }
    }
}

/// Core non-distorting image resizing engine.
public final class ImageResizeEngine: @unchecked Sendable {

    public static let shared = ImageResizeEngine()

    public init() {}

    // MARK: - Mathematical Dimension Calculation

    /// Calculates strict aspect-ratio preserving dimensions according to Microsoft PowerToys rules.
    /// Never stretches or distorts. Always fits within bounding limits.
    public static func calculateDimensions(
        original: ImageDimensions,
        mode: ResizeMode,
        targetWidth: Int? = nil,
        targetHeight: Int? = nil,
        percentage: Double? = nil,
        preset: ResizePreset? = nil,
        allowUpscaling: Bool = false
    ) -> ImageDimensions {
        let origW = original.width
        let origH = original.height

        guard origW > 0 && origH > 0 else {
            return original
        }

        switch mode {
        case .preset:
            let bounds = preset?.dimensions ?? ResizePreset.medium.dimensions
            return fitWithinBounds(
                original: original,
                maxWidth: bounds.width,
                maxHeight: bounds.height,
                allowUpscaling: allowUpscaling
            )

        case .fit:
            let tw = max(1, targetWidth ?? origW)
            let th = max(1, targetHeight ?? origH)
            return fitWithinBounds(
                original: original,
                maxWidth: tw,
                maxHeight: th,
                allowUpscaling: allowUpscaling
            )

        case .widthOnly:
            let tw = max(1, targetWidth ?? origW)
            var scale = Double(tw) / Double(origW)
            if !allowUpscaling {
                scale = min(1.0, scale)
            }
            let outW = max(1, Int(round(Double(origW) * scale)))
            let outH = max(1, Int(round(Double(origH) * scale)))
            return ImageDimensions(width: outW, height: outH)

        case .heightOnly:
            let th = max(1, targetHeight ?? origH)
            var scale = Double(th) / Double(origH)
            if !allowUpscaling {
                scale = min(1.0, scale)
            }
            let outW = max(1, Int(round(Double(origW) * scale)))
            let outH = max(1, Int(round(Double(origH) * scale)))
            return ImageDimensions(width: outW, height: outH)

        case .percentage:
            let pct = max(1.0, percentage ?? 100.0)
            var scale = pct / 100.0
            if !allowUpscaling {
                scale = min(1.0, scale)
            }
            let outW = max(1, Int(round(Double(origW) * scale)))
            let outH = max(1, Int(round(Double(origH) * scale)))
            return ImageDimensions(width: outW, height: outH)
        }
    }

    /// Fits an original size inside maximum bounding box (maxWidth x maxHeight)
    /// scale = min(TW / W, TH / H)
    /// Never crops, never stretches. Clamps scale to 1.0 if allowUpscaling is false.
    public static func fitWithinBounds(
        original: ImageDimensions,
        maxWidth: Int,
        maxHeight: Int,
        allowUpscaling: Bool
    ) -> ImageDimensions {
        let origW = original.width
        let origH = original.height

        guard origW > 0, origH > 0, maxWidth > 0, maxHeight > 0 else {
            return original
        }

        let scaleW = Double(maxWidth) / Double(origW)
        let scaleH = Double(maxHeight) / Double(origH)
        var scale = min(scaleW, scaleH)

        if !allowUpscaling {
            scale = min(1.0, scale)
        }

        var outW = max(1, Int(round(Double(origW) * scale)))
        var outH = max(1, Int(round(Double(origH) * scale)))

        // Guard against integer-rounding edge cases exceeding bounds
        if outW > maxWidth {
            outW = maxWidth
            outH = max(1, Int(round(Double(outW) / original.aspectRatio)))
        }
        if outH > maxHeight {
            outH = maxHeight
            outW = max(1, Int(round(Double(outH) * original.aspectRatio)))
        }

        return ImageDimensions(width: outW, height: outH)
    }

    // MARK: - Metadata & Reading

    /// Reads metadata from an image URL without decoding pixel buffers into memory.
    public static func readImageProperties(at url: URL) throws -> (dimensions: ImageDimensions, utType: UTType?, formatName: String) {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
            throw ImageResizeError.fileNotFound(url)
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options as CFDictionary) as? [CFString: Any] else {
            throw ImageResizeError.unsupportedOrCorruptedFormat(url)
        }

        guard let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int,
              pixelWidth > 0, pixelHeight > 0 else {
            throw ImageResizeError.unsupportedOrCorruptedFormat(url)
        }

        // Account for EXIF orientation (orientations 5, 6, 7, 8 swap width and height)
        let orientation = (properties[kCGImagePropertyOrientation] as? UInt32) ?? 1
        let isTransposed = orientation >= 5 && orientation <= 8
        let displayWidth = isTransposed ? pixelHeight : pixelWidth
        let displayHeight = isTransposed ? pixelWidth : pixelHeight

        let typeIdentifier = CGImageSourceGetType(source) as String?
        let utType = typeIdentifier != nil ? UTType(typeIdentifier!) : nil
        let formatName = utType?.localizedDescription ?? (url.pathExtension.uppercased() + " Image")

        return (ImageDimensions(width: displayWidth, height: displayHeight), utType, formatName)
    }

    // MARK: - Resizing & Saving

    /// Resizes an image from sourceURL to destinationURL preserving aspect ratio.
    public func resizeImage(
        from sourceURL: URL,
        to destinationURL: URL,
        targetDimensions: ImageDimensions,
        outputFormat: OutputFormat,
        quality: Double,
        preserveMetadata: Bool = true
    ) throws {
        let readOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, readOptions as CFDictionary) else {
            throw ImageResizeError.fileNotFound(sourceURL)
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else {
            throw ImageResizeError.unsupportedOrCorruptedFormat(sourceURL)
        }

        // Determine destination UTType
        let destinationUTType: CFString
        if let explicitUTType = outputFormat.utType {
            destinationUTType = explicitUTType.identifier as CFString
        } else if let sourceUTType = CGImageSourceGetType(source) {
            destinationUTType = sourceUTType
        } else {
            destinationUTType = UTType.jpeg.identifier as CFString
        }

        // Create destination
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            destinationUTType,
            frameCount,
            nil
        ) else {
            throw ImageResizeError.cannotCreateDestination(destinationURL)
        }

        // Prepare frame options
        var frameOptions: [CFString: Any] = [:]
        if outputFormat.supportsQuality || (outputFormat == .original && isLossyType(destinationUTType as String)) {
            frameOptions[kCGImageDestinationLossyCompressionQuality] = quality as CFNumber
        }

        // Process each frame (preserves animated GIFs / APNG / multi-frame TIFFs)
        for frameIndex in 0..<frameCount {
            let resizedCGImage = try resizeSingleFrame(
                source: source,
                index: frameIndex,
                targetDimensions: targetDimensions
            )

            // Extract metadata if needed
            var frameProperties: [CFString: Any] = [:]
            if preserveMetadata,
               let sourceProps = CGImageSourceCopyPropertiesAtIndex(source, frameIndex, nil) as? [CFString: Any] {
                frameProperties = cleanMetadataForResizedImage(
                    sourceProps: sourceProps,
                    newWidth: resizedCGImage.width,
                    newHeight: resizedCGImage.height
                )
            }

            // Merge compression quality into frame properties
            for (key, value) in frameOptions {
                frameProperties[key] = value
            }

            CGImageDestinationAddImage(destination, resizedCGImage, frameProperties as CFDictionary)
        }

        // Finalize writing
        guard CGImageDestinationFinalize(destination) else {
            throw ImageResizeError.failedToFinalizeImage(destinationURL)
        }
    }

    // MARK: - Frame Processing

    private func resizeSingleFrame(
        source: CGImageSource,
        index: Int,
        targetDimensions: ImageDimensions
    ) throws -> CGImage {
        let maxPixelSize = max(targetDimensions.width, targetDimensions.height)

        // Apple Image I/O thumbnail generation with transform handles orientation natively
        // and uses efficient downsampling without holding full uncompressed image in RAM.
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, index, thumbnailOptions as CFDictionary) {
            // If the thumbnail matches or is downscaled nicely, return it
            if thumbnail.width == targetDimensions.width && thumbnail.height == targetDimensions.height {
                return thumbnail
            }

            // If thumbnail is within 1 pixel (due to integer aspect ratio rounding), return it
            if abs(thumbnail.width - targetDimensions.width) <= 1 && abs(thumbnail.height - targetDimensions.height) <= 1 {
                return thumbnail
            }

            // If thumbnail size is significantly different (e.g. upscaled or transform orientation difference),
            // draw into an explicit CGContext with high-quality interpolation
            return try drawResizedImage(
                image: thumbnail,
                targetWidth: targetDimensions.width,
                targetHeight: targetDimensions.height
            )
        }

        // Fallback: create direct CGImage and draw
        guard let fullImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
            throw ImageResizeError.unsupportedOrCorruptedFormat(URL(fileURLWithPath: "frame-\(index)"))
        }

        return try drawResizedImage(
            image: fullImage,
            targetWidth: targetDimensions.width,
            targetHeight: targetDimensions.height
        )
    }

    /// Renders an image into a CoreGraphics context with high interpolation quality
    private func drawResizedImage(image: CGImage, targetWidth: Int, targetHeight: Int) throws -> CGImage {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = image.bitmapInfo.rawValue != 0 ? image.bitmapInfo : CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: image.bitsPerComponent > 0 ? image.bitsPerComponent : 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw ImageResizeError.invalidDimensions("Cannot allocate graphics context for \(targetWidth) × \(targetHeight)")
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let result = context.makeImage() else {
            throw ImageResizeError.invalidDimensions("Failed to generate image from graphics context")
        }

        return result
    }

    // MARK: - Metadata Utilities

    private func cleanMetadataForResizedImage(
        sourceProps: [CFString: Any],
        newWidth: Int,
        newHeight: Int
    ) -> [CFString: Any] {
        var cleanProps = sourceProps
        // Update pixel dimensions in root metadata
        cleanProps[kCGImagePropertyPixelWidth] = newWidth as CFNumber
        cleanProps[kCGImagePropertyPixelHeight] = newHeight as CFNumber

        // Reset orientation to 1 since transformed during thumbnail generation
        cleanProps[kCGImagePropertyOrientation] = 1 as CFNumber

        // Clean TIFF and EXIF sub-dictionaries if present
        if var tiffDict = cleanProps[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiffDict[kCGImagePropertyTIFFOrientation] = 1 as CFNumber
            cleanProps[kCGImagePropertyTIFFDictionary] = tiffDict
        }

        if var exifDict = cleanProps[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exifDict[kCGImagePropertyExifPixelXDimension] = newWidth as CFNumber
            exifDict[kCGImagePropertyExifPixelYDimension] = newHeight as CFNumber
            cleanProps[kCGImagePropertyExifDictionary] = exifDict
        }

        return cleanProps
    }

    private func isLossyType(_ identifier: String) -> Bool {
        return identifier == UTType.jpeg.identifier ||
               identifier == UTType.heic.identifier ||
               identifier == UTType.webP.identifier
    }
}
