import SwiftUI
import AppKit

// MARK: - San Francisco Precision Utility Theme Tokens
public struct PrecisionTheme {
    // Dynamic Colors matching Stitch design system
    public static var background: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 24/255, green: 24/255, blue: 27/255, alpha: 1.0) // #18181B
                : NSColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0) // #F8F9FA
        }))
    }

    public static var cardBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 32/255, green: 32/255, blue: 36/255, alpha: 1.0)
                : NSColor.white
        }))
    }

    public static var cardHeaderBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 38/255, green: 38/255, blue: 42/255, alpha: 1.0)
                : NSColor(red: 250/255, green: 250/255, blue: 252/255, alpha: 1.0) // #FAFAFC
        }))
    }

    public static var recessedBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.04)
                : NSColor.black.withAlphaComponent(0.03)
        }))
    }

    public static var border: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.12)
                : NSColor.black.withAlphaComponent(0.08)
        }))
    }

    public static var borderSubtle: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.06)
                : NSColor.black.withAlphaComponent(0.04)
        }))
    }

    // Accents
    public static let blue = Color(red: 0/255, green: 102/255, blue: 255/255) // #0066FF
    public static let blueHover = Color(red: 0/255, green: 85/255, blue: 214/255) // #0055D6
    public static let blueLight = Color(red: 0/255, green: 102/255, blue: 255/255).opacity(0.08)

    public static let green = Color(red: 36/255, green: 138/255, blue: 61/255) // #248A3D
    public static let greenLight = Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.12) // #34C759/10

    public static let danger = Color(red: 255/255, green: 59/255, blue: 48/255) // #FF3B30
    public static let dangerLight = Color(red: 255/255, green: 59/255, blue: 48/255).opacity(0.10)

    public static let purple = Color(red: 88/255, green: 86/255, blue: 214/255) // #5856D6

    // Text
    public static let textPrimary = Color.primary
    public static let textSecondary = Color(red: 110/255, green: 110/255, blue: 115/255) // #6E6E73
    public static let textTertiary = Color(red: 134/255, green: 134/255, blue: 139/255) // #86868B
}

// MARK: - View Modifiers & Containers

public struct StitchCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 12
    public var padding: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PrecisionTheme.cardBackground)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(PrecisionTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
    }
}

public extension View {
    func stitchCard(cornerRadius: CGFloat = 12, padding: CGFloat = 0) -> some View {
        self.modifier(StitchCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Overlaid Format Badge

public struct FormatBadge: View {
    public let format: String

    public init(format: String) {
        self.format = format.uppercased()
    }

    private var badgeColor: Color {
        switch format {
        case "HEIC", "HEIF":
            return PrecisionTheme.blue
        case "PNG":
            return PrecisionTheme.purple
        case "TIFF", "TIF":
            return Color(red: 29/255, green: 29/255, blue: 31/255)
        case "WEBP":
            return Color(red: 0/255, green: 128/255, blue: 128/255)
        case "GIF":
            return Color.orange
        default: // JPG / JPEG
            return Color.black.opacity(0.75)
        }
    }

    public var body: some View {
        Text(format)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(badgeColor)
            .cornerRadius(3)
    }
}

// MARK: - Reduction Pill

public struct ReductionPill: View {
    public let percentage: Double

    public init(percentage: Double) {
        self.percentage = percentage
    }

    public var body: some View {
        HStack(spacing: 2) {
            Text(String(format: "-%.1f%%", abs(percentage)))
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundColor(PrecisionTheme.green)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(PrecisionTheme.greenLight)
        .cornerRadius(4)
    }
}

// MARK: - Status Ready Pill

public struct StatusPill: View {
    public let title: String
    public var isPositive: Bool = true

    public init(title: String, isPositive: Bool = true) {
        self.title = title
        self.isPositive = isPositive
    }

    public var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(isPositive ? PrecisionTheme.green : PrecisionTheme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isPositive ? PrecisionTheme.greenLight : PrecisionTheme.recessedBackground)
            .clipShape(Capsule())
    }
}

// MARK: - Zero-Distortion Guarantee Card

public struct MathematicalGuaranteeCard: View {
    public init() {}

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundColor(PrecisionTheme.blue)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Zero-Distortion Guarantee")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(PrecisionTheme.textPrimary)

                HStack(spacing: 4) {
                    Text("Scaled proportionally via")
                        .font(.system(size: 11))
                        .foregroundColor(PrecisionTheme.textSecondary)

                    Text("min(TW/W, TH/H)")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(PrecisionTheme.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(PrecisionTheme.cardBackground)
                        .cornerRadius(3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(PrecisionTheme.borderSubtle, lineWidth: 1)
                        )

                    Text(". Strict ratio.")
                        .font(.system(size: 11))
                        .foregroundColor(PrecisionTheme.textSecondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrecisionTheme.recessedBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(PrecisionTheme.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Keyboard Shortcut Badge

public struct ShortcutBadge: View {
    public let shortcut: String

    public init(_ shortcut: String) {
        self.shortcut = shortcut
    }

    public var body: some View {
        Text(shortcut)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.2))
            .cornerRadius(4)
    }
}
