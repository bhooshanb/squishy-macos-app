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
