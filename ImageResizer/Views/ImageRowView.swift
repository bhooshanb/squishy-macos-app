import SwiftUI

public struct ImageRowView: View {
    @ObservedObject public var item: ImageItem
    public let calculatedDimensions: ImageDimensions?
    public let onRemove: () -> Void

    public init(
        item: ImageItem,
        calculatedDimensions: ImageDimensions?,
        onRemove: @escaping () -> Void
    ) {
        self.item = item
        self.calculatedDimensions = calculatedDimensions
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            thumbnailView
                .frame(width: 48, height: 48)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))

            // File Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Text(item.originalDimensions.description)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))

                    Text(item.formatName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))

                    Text(item.formattedFileSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Calculated Output Dimensions
            if let target = calculatedDimensions {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    Text(target.description)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(5)
                }
            }

            // Status Indicator
            statusView

            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Remove image from queue")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumb = item.thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(NSColor.quaternaryLabelColor).opacity(0.2)
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            }
            .onAppear {
                loadThumbnail()
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .idle:
            EmptyView()
        case .processing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 20, height: 20)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
                .help("Successfully resized")
        case .failed(let error):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16))
                .help(error)
        }
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let thumb = ImageFileService.shared.generateThumbnail(for: self.item.url, maxPixelSize: 96)
            DispatchQueue.main.async {
                self.item.thumbnail = thumb
            }
        }
    }
}
