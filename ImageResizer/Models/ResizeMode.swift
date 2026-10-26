import Foundation

/// Represents the resizing mode selected by the user.
public enum ResizeMode: String, CaseIterable, Identifiable, Codable {
    case preset = "preset"
    case fit = "fit"                // Fit within custom max width & max height bounds
    case widthOnly = "widthOnly"    // Specify width, derive height from aspect ratio
    case heightOnly = "heightOnly"  // Specify height, derive width from aspect ratio
    case percentage = "percentage"  // Scale percentage relative to original size

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .preset: return "Preset"
        case .fit: return "Fit Within Bounds"
        case .widthOnly: return "Width"
        case .heightOnly: return "Height"
        case .percentage: return "Percentage"
        }
    }

    public var systemImageName: String {
        switch self {
        case .preset: return "square.grid.2x2"
        case .fit: return "arrow.up.left.and.arrow.down.right"
        case .widthOnly: return "arrow.left.and.right"
        case .heightOnly: return "arrow.up.and.down"
        case .percentage: return "percent"
        }
    }
}
