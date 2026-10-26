import Foundation

/// A predefined maximum bounding dimension preset inspired by Microsoft PowerToys.
public struct ResizePreset: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var maxWidth: Int
    public var maxHeight: Int
    public var isBuiltIn: Bool

    public init(id: UUID = UUID(), name: String, maxWidth: Int, maxHeight: Int, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.isBuiltIn = isBuiltIn
    }

    public var dimensions: ImageDimensions {
        ImageDimensions(width: maxWidth, height: maxHeight)
    }

    public var subtitle: String {
        "Fit within \(maxWidth) × \(maxHeight)"
    }

    // Built-in presets matching PowerToys conventions
    public static let small = ResizePreset(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        name: "Small",
        maxWidth: 854,
        maxHeight: 480,
        isBuiltIn: true
    )

    public static let medium = ResizePreset(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
        name: "Medium",
        maxWidth: 1366,
        maxHeight: 768,
        isBuiltIn: true
    )

    public static let large = ResizePreset(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
        name: "Large",
        maxWidth: 1920,
        maxHeight: 1080,
        isBuiltIn: true
    )

    public static let extraLarge = ResizePreset(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
        name: "Extra Large (4K)",
        maxWidth: 3840,
        maxHeight: 2160,
        isBuiltIn: true
    )

    public static let mobile = ResizePreset(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
        name: "Mobile (Portrait)",
        maxWidth: 1080,
        maxHeight: 1920,
        isBuiltIn: true
    )

    public static let defaultPresets: [ResizePreset] = [
        .small,
        .medium,
        .large,
        .extraLarge,
        .mobile
    ]
}
