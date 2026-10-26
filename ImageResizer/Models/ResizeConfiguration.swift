import Foundation

public enum OutputDestinationMode: String, CaseIterable, Identifiable, Codable {
    case subfolder = "subfolder"       // Beside original in a subfolder (e.g. "Resized")
    case sameFolder = "sameFolder"     // Beside original in the same directory
    case customFolder = "customFolder" // User-selected directory

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .subfolder: return "Subfolder beside original"
        case .sameFolder: return "Same folder as original"
        case .customFolder: return "Custom folder…"
        }
    }
}

public enum CollisionHandling: String, CaseIterable, Identifiable, Codable {
    case renameWithNumber = "renameWithNumber" // e.g. photo-resized (1).jpg
    case overwrite = "overwrite"               // Overwrite existing file
    case skip = "skip"                         // Skip processing

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .renameWithNumber: return "Keep both (append number)"
        case .overwrite: return "Overwrite existing file"
        case .skip: return "Skip if file exists"
        }
    }
}

/// Complete configuration for a resize operation.
public struct ResizeConfiguration: Codable, Equatable {
    public var mode: ResizeMode
    public var selectedPresetId: UUID
    public var customWidth: Int
    public var customHeight: Int
    public var percentage: Double
    public var allowUpscaling: Bool
    public var outputFormat: OutputFormat
    public var quality: Double // 0.1 to 1.0
    public var destinationMode: OutputDestinationMode
    public var subfolderName: String
    public var customDestinationPath: String?
    public var filenameSuffix: String
    public var appendPresetNameToFilename: Bool
    public var collisionHandling: CollisionHandling
    public var preserveMetadata: Bool

    public init(
        mode: ResizeMode = .preset,
        selectedPresetId: UUID = ResizePreset.medium.id,
        customWidth: Int = 1920,
        customHeight: Int = 1080,
        percentage: Double = 50.0,
        allowUpscaling: Bool = false,
        outputFormat: OutputFormat = .original,
        quality: Double = 0.85,
        destinationMode: OutputDestinationMode = .subfolder,
        subfolderName: String = "Resized",
        customDestinationPath: String? = nil,
        filenameSuffix: String = "-resized",
        appendPresetNameToFilename: Bool = false,
        collisionHandling: CollisionHandling = .renameWithNumber,
        preserveMetadata: Bool = true
    ) {
        self.mode = mode
        self.selectedPresetId = selectedPresetId
        self.customWidth = max(1, customWidth)
        self.customHeight = max(1, customHeight)
        self.percentage = max(1.0, percentage)
        self.allowUpscaling = allowUpscaling
        self.outputFormat = outputFormat
        self.quality = min(max(0.05, quality), 1.0)
        self.destinationMode = destinationMode
        self.subfolderName = subfolderName
        self.customDestinationPath = customDestinationPath
        self.filenameSuffix = filenameSuffix
        self.appendPresetNameToFilename = appendPresetNameToFilename
        self.collisionHandling = collisionHandling
        self.preserveMetadata = preserveMetadata
    }

    public static let `default` = ResizeConfiguration()
}
