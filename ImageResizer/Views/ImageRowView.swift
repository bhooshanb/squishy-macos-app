import SwiftUI

public struct ImageRowView: View {
    @ObservedObject public var item: ImageItem
    public let calculatedDimensions: ImageDimensions?
    public let onRemove: () -> Void

    @State private var isHovering: Bool = false

    public init(
        item: ImageItem,
        calculatedDimensions: ImageDimensions?,
        onRemove: @escaping () -> Void
    ) {
        self.item = item
        self.calculatedDimensions = calculatedDimensions
        self.onRemove = onRemove
    }

    private var reductionPercentage: Double {
        guard let target = calculatedDimensions,
              item.originalDimensions.width > 0,
              item.originalDimensions.height > 0 else {
            return 0.0
        }
        let origArea = Double(item.originalDimensions.width * item.originalDimensions.height)
        let targetArea = Double(target.width * target.height)
        let diff = origArea - targetArea
        return (diff / origArea) * 100.0
    }

    private var estimatedSizeString: String {
        guard let target = calculatedDimensions,
              item.originalDimensions.width > 0,
              item.originalDimensions.height > 0 else {
            return item.formattedFileSize
        }
        let origArea = Double(item.originalDimensions.width * item.originalDimensions.height)
        let targetArea = Double(target.width * target.height)
        let ratio = min(1.0, max(0.05, targetArea / origArea))
        let estimatedBytes = Int64(Double(item.fileSize) * ratio)
        return "~\(ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file))"
    }

    private var aspectPreservedString: String {
        let (num, den) = item.originalDimensions.aspectRatioFraction
        return "\(num):\(den) Preserved"
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with Overlaid Format Badge
            ZStack(alignment: .bottomTrailing) {
                thumbnailView
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(PrecisionTheme.border, lineWidth: 1)
                    )

                FormatBadge(format: item.formatName)
                    .offset(x: 2, y: 2)
            }
            .frame(width: 44, height: 44)

            // Asset & Original Specs
            VStack(alignment: .leading, spacing: 3) {
                Text(item.filename)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(isHovering ? PrecisionTheme.blue : PrecisionTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 5) {
                    Text(item.originalDimensions.description)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(PrecisionTheme.textTertiary)

                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(PrecisionTheme.textTertiary.opacity(0.6))

                    Text(item.formattedFileSize)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(PrecisionTheme.textTertiary)
                }
            }

            Spacer(minLength: 8)

            // Target Output
            if let target = calculatedDimensions {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(target.description)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(PrecisionTheme.textPrimary)

                    Text(aspectPreservedString)
                        .font(.system(size: 10))
                        .foregroundColor(PrecisionTheme.textTertiary)
                }
                .frame(minWidth: 90, alignment: .trailing)

                // Reduction Pill & Estimated Size
                VStack(alignment: .trailing, spacing: 2) {
                    if reductionPercentage > 1.0 {
                        ReductionPill(percentage: reductionPercentage)
                    } else if reductionPercentage < -1.0 {
                        Text(String(format: "+%.0f%%", abs(reductionPercentage)))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(4)
                    } else {
                        Text("100%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(PrecisionTheme.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(PrecisionTheme.recessedBackground)
                            .cornerRadius(4)
                    }

                    Text(estimatedSizeString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(PrecisionTheme.textTertiary)
                }
                .frame(minWidth: 70, alignment: .trailing)
            }

            // Status or Remove Button
            statusOrRemoveView
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? PrecisionTheme.recessedBackground : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumb = item.thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                PrecisionTheme.recessedBackground
                Image(systemName: "photo")
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .font(.system(size: 14))
            }
            .onAppear {
                loadThumbnail()
            }
        }
    }

    @ViewBuilder
    private var statusOrRemoveView: some View {
        switch item.status {
        case .idle:
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isHovering ? PrecisionTheme.danger : PrecisionTheme.textTertiary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Remove image from queue")

        case .processing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)

        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(PrecisionTheme.green)
                .font(.system(size: 16))
                .help("Successfully resized")

        case .failed(let error):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(PrecisionTheme.danger)
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
