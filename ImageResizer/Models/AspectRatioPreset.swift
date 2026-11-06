import Foundation

/// Common photography and social media aspect ratio bounding targets.
public struct AspectRatioPreset: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let ratioLabel: String
    public let width: Int
    public let height: Int
    public let icon: String
    public let subtitle: String

    public init(id: String, name: String, ratioLabel: String, width: Int, height: Int, icon: String, subtitle: String) {
        self.id = id
        self.name = name
        self.ratioLabel = ratioLabel
        self.width = width
        self.height = height
        self.icon = icon
        self.subtitle = subtitle
    }

    public var dimensions: ImageDimensions {
        ImageDimensions(width: width, height: height)
    }

    /// Inverts width and height (e.g. 4:3 -> 3:4, 16:9 -> 9:16)
    public func inverted() -> AspectRatioPreset {
        guard width != height else { return self }

        let parts = ratioLabel.split(separator: ":")
        let newRatioLabel: String
        if parts.count == 2 {
            newRatioLabel = "\(parts[1]):\(parts[0])"
        } else {
            newRatioLabel = ratioLabel
        }

        let newIcon: String
        if icon == "rectangle.portrait" {
            newIcon = "rectangle"
        } else if icon == "rectangle" {
            newIcon = "rectangle.portrait"
        } else if icon == "tv" {
            newIcon = "iphone"
        } else if icon == "iphone" {
            newIcon = "tv"
        } else {
            newIcon = icon
        }

        let newName: String
        if name == "Standard Photo" && newRatioLabel == "3:4" {
            newName = "Portrait (3:4)"
        } else if name == "Widescreen" && newRatioLabel == "9:16" {
            newName = "Vertical Video"
        } else if name == "Story / Reels" && newRatioLabel == "16:9" {
            newName = "Landscape Video"
        } else if name == "Portrait" && newRatioLabel == "5:4" {
            newName = "Landscape (5:4)"
        } else if name == "35mm DSLR" && newRatioLabel == "2:3" {
            newName = "Portrait (2:3)"
        } else if name == "Social Post" && newRatioLabel == "1:1.91" {
            newName = "Vertical Post"
        } else if name.contains("Portrait") {
            newName = name.replacingOccurrences(of: "Portrait", with: "Landscape")
        } else if name.contains("Landscape") {
            newName = name.replacingOccurrences(of: "Landscape", with: "Portrait")
        } else {
            newName = "\(name) (Inverted)"
        }

        return AspectRatioPreset(
            id: "\(id)_inv",
            name: newName,
            ratioLabel: newRatioLabel,
            width: height,
            height: width,
            icon: newIcon,
            subtitle: "Inverted \(subtitle)"
        )
    }

    public static let all: [AspectRatioPreset] = [
        AspectRatioPreset(
            id: "1_1_square",
            name: "Square",
            ratioLabel: "1:1",
            width: 1080,
            height: 1080,
            icon: "square",
            subtitle: "Instagram Post, Profile"
        ),
        AspectRatioPreset(
            id: "4_5_portrait",
            name: "Portrait",
            ratioLabel: "4:5",
            width: 1080,
            height: 1350,
            icon: "rectangle.portrait",
            subtitle: "Instagram Feed Portrait"
        ),
        AspectRatioPreset(
            id: "9_16_story",
            name: "Story / Reels",
            ratioLabel: "9:16",
            width: 1080,
            height: 1920,
            icon: "iphone",
            subtitle: "TikTok, Reels, Stories"
        ),
        AspectRatioPreset(
            id: "16_9_landscape",
            name: "Widescreen",
            ratioLabel: "16:9",
            width: 1920,
            height: 1080,
            icon: "tv",
            subtitle: "YouTube, Landscape"
        ),
        AspectRatioPreset(
            id: "1_91_1_post",
            name: "Social Post",
            ratioLabel: "1.91:1",
            width: 1200,
            height: 630,
            icon: "bubble.left.and.bubble.right",
            subtitle: "Twitter / X, LinkedIn, FB"
        ),
        AspectRatioPreset(
            id: "4_3_photo",
            name: "Standard Photo",
            ratioLabel: "4:3",
            width: 1600,
            height: 1200,
            icon: "camera",
            subtitle: "iPad, Classic Monitor"
        ),
        AspectRatioPreset(
            id: "3_2_dslr",
            name: "35mm DSLR",
            ratioLabel: "3:2",
            width: 1800,
            height: 1200,
            icon: "camera.viewfinder",
            subtitle: "35mm Photography"
        )
    ]
}
