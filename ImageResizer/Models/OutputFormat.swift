import Foundation
import UniformTypeIdentifiers

/// Image output format options.
public enum OutputFormat: String, CaseIterable, Identifiable, Codable {
    case original = "original"
    case jpeg = "jpeg"
    case png = "png"
    case heic = "heic"
    case webp = "webp"
    case tiff = "tiff"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .original: return "Same as original"
        case .jpeg: return "JPEG (.jpg)"
        case .png: return "PNG (.png)"
        case .heic: return "HEIC (.heic)"
        case .webp: return "WebP (.webp)"
        case .tiff: return "TIFF (.tiff)"
        }
    }

    public var utType: UTType? {
        switch self {
        case .original: return nil
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .webp: return .webP
        case .tiff: return .tiff
        }
    }

    public var fileExtension: String {
        switch self {
        case .original: return ""
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .webp: return "webp"
        case .tiff: return "tiff"
        }
    }

    /// Whether this format supports lossy compression quality control (0.0 to 1.0)
    public var supportsQuality: Bool {
        switch self {
        case .jpeg, .heic, .webp:
            return true
        case .png, .tiff, .original:
            return false
        }
    }
}
