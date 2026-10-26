import SwiftUI

public struct EmptyDropZoneView: View {
    public let onSelectFiles: () -> Void

    public init(onSelectFiles: @escaping () -> Void) {
        self.onSelectFiles = onSelectFiles
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 96, height: 96)

                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 8) {
                Text("Resize images in seconds.")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)

                Text("Drop images here or choose files to get started.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onSelectFiles) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Choose Files…")
                }
                .font(.body.weight(.medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)

            HStack(spacing: 8) {
                formatBadge("JPEG")
                formatBadge("PNG")
                formatBadge("HEIC")
                formatBadge("WebP")
                formatBadge("TIFF")
                formatBadge("GIF")
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func formatBadge(_ name: String) -> some View {
        Text(name)
            .font(.caption2.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(NSColor.quaternaryLabelColor).opacity(0.2))
            .cornerRadius(4)
    }
}
