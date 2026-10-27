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

    public var aspectRatioFraction: (Int, Int) {
        guard width > 0 && height > 0 else { return (1, 1) }
        func gcd(_ a: Int, _ b: Int) -> Int {
            b == 0 ? a : gcd(b, a % b)
        }
        let divisor = gcd(width, height)
        let num = width / divisor
        let den = height / divisor
        // If reduced fraction is overly large (e.g. 1921/1081), find closest standard ratio
        if num > 25 || den > 25 {
            let ratio = Double(width) / Double(height)
            let standards: [(Int, Int, Double)] = [
                (1, 1, 1.0),
                (4, 3, 4.0/3.0),
                (3, 4, 3.0/4.0),
                (16, 9, 16.0/9.0),
                (9, 16, 9.0/16.0),
                (3, 2, 3.0/2.0),
                (2, 3, 2.0/3.0),
                (5, 4, 5.0/4.0),
                (4, 5, 4.0/5.0),
                (21, 9, 21.0/9.0)
            ]
            if let closest = standards.first(where: { abs($0.2 - ratio) < 0.05 }) {
                return (closest.0, closest.1)
            }
        }
        return (num, den)
    }

    public var description: String {
        "\(width) × \(height)"
    }

    public var formattedWithMegapixels: String {
        let megapixels = Double(width * height) / 1_000_000.0
        return String(format: "%d × %d (%.1f MP)", width, height, megapixels)
    }
}
