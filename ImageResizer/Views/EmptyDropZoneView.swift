import SwiftUI

public struct EmptyDropZoneView: View {
    public let onSelectFiles: () -> Void

    public init(onSelectFiles: @escaping () -> Void) {
        self.onSelectFiles = onSelectFiles
    }

    public var body: some View {
        VStack(spacing: 22) {
            Spacer()

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(PrecisionTheme.blueLight)
                    .frame(width: 84, height: 84)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 38))
                    .foregroundColor(PrecisionTheme.blue)
            }

            // Title & Subtitle
            VStack(spacing: 6) {
                Text("Squishy")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(PrecisionTheme.textPrimary)

                Text("High-performance macOS native batch image resizer.")
                    .font(.system(size: 13))
                    .foregroundColor(PrecisionTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Strict aspect ratio preservation • Zero distortion • Apple Silicon Metal accelerated")
                    .font(.system(size: 11))
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }

            // Action Button
            Button(action: onSelectFiles) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Choose Images…")
                        .font(.system(size: 13, weight: .semibold))
                    ShortcutBadge("⌘O")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(PrecisionTheme.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: PrecisionTheme.blue.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)

            // Supported Format Badges
            HStack(spacing: 6) {
                FormatBadge(format: "JPEG")
                FormatBadge(format: "PNG")
                FormatBadge(format: "HEIC")
                FormatBadge(format: "WebP")
                FormatBadge(format: "TIFF")
                FormatBadge(format: "GIF")
            }
            .padding(.top, 4)

            Spacer()

            // Footer branding
            HStack(spacing: 4) {
                Text("Created by")
                    .foregroundColor(PrecisionTheme.textTertiary)
                Link("Silverstone Labs", destination: URL(string: "https://apps.silverstonelabs.in")!)
                    .foregroundColor(PrecisionTheme.blue)
                    .underline()
            }
            .font(.system(size: 10.5))
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(PrecisionTheme.background)
    }
}
