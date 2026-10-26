import Foundation

/// Represents integer pixel width and height.
public struct ImageDimensions: Equatable, Codable, Hashable, CustomStringConvertible {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
    }

    public var aspectRatio: Double {
        guard height > 0 else { return 0 }
        return Double(width) / Double(height)
    }

    public var isLandscape: Bool {
        width > height
    }

    public var isPortrait: Bool {
        height > width
    }

    public var isSquare: Bool {
        width == height && width > 0
    }

    public var description: String {
        "\(width) × \(height)"
    }

    public var formattedWithMegapixels: String {
        let megapixels = Double(width * height) / 1_000_000.0
        return String(format: "%d × %d (%.1f MP)", width, height, megapixels)
    }
}
