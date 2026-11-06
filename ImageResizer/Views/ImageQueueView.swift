import SwiftUI

public struct ImageQueueView: View {
    @Binding public var items: [ImageItem]
    public let configuration: ResizeConfiguration
    public let selectedPreset: ResizePreset?
    public let isProcessing: Bool
    public let onAddMore: () -> Void
    public let onClearAll: () -> Void

    public init(
        items: Binding<[ImageItem]>,
        configuration: ResizeConfiguration,
        selectedPreset: ResizePreset?,
        isProcessing: Bool = false,
        onAddMore: @escaping () -> Void,
        onClearAll: @escaping () -> Void
    ) {
        self._items = items
        self.configuration = configuration
        self.selectedPreset = selectedPreset
        self.isProcessing = isProcessing
        self.onAddMore = onAddMore
        self.onClearAll = onClearAll
    }

    private var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.fileSize }
    }

    private var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    public var body: some View {
        VStack(spacing: 14) {
            // macOS File List Table Card
            fileListTableCard

            // Hardware & Engine Callout Bar
            hardwareCalloutBar
        }
        .padding(16)
        .background(PrecisionTheme.background)
    }

    // MARK: - File List Table Card
    private var fileListTableCard: some View {
        VStack(spacing: 0) {
            // Table Header Bar
            HStack {
                Text("Asset & Original Specs")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)

                Spacer()

                Text("Target Output")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .frame(minWidth: 90, alignment: .trailing)

                Text("Reduction")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .frame(minWidth: 70, alignment: .trailing)

                Spacer()
                    .frame(width: 30) // For remove button column
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(PrecisionTheme.cardHeaderBackground)

            Divider()
                .background(PrecisionTheme.border)

            // Scrollable List
            if items.isEmpty {
                ContentUnavailableView("No matching files", systemImage: "line.3.horizontal.decrease.circle", description: Text("Choose another queue filter or add files."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
              ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let targetDimensions = item.mediaKind == .video ? nil : ImageResizeEngine.calculateDimensions(
                            original: item.originalDimensions,
                            mode: configuration.mode,
                            targetWidth: configuration.customWidth,
                            targetHeight: configuration.customHeight,
                            percentage: configuration.percentage,
                            preset: selectedPreset,
                            allowUpscaling: configuration.allowUpscaling
                        )

                        ImageRowView(
                            item: item,
                            calculatedDimensions: targetDimensions,
                            onRemove: {
                                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                    items.remove(at: idx)
                                }
                            },
                            canRemove: !isProcessing,
                            videoBitratePreset: configuration.videoBitratePreset
                        )

                        if index < items.count - 1 {
                            Divider()
                                .background(PrecisionTheme.borderSubtle)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.vertical, 4)
              }
            }
        }
        .background(PrecisionTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(PrecisionTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Hardware & Acceleration Callout
    private var hardwareCalloutBar: some View {
        HStack {
            Image(systemName: "cpu")
                .font(.system(size: 12))
                .foregroundColor(PrecisionTheme.blue)

            Text("Images: Metal / vImage resizing · Videos: H.264 bitrate compression")
                .font(.system(size: 11))
                .foregroundColor(PrecisionTheme.textSecondary)

            Spacer()

            Text("\(formattedTotalSize) / \(items.count) items")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundColor(PrecisionTheme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(PrecisionTheme.cardBackground)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(PrecisionTheme.borderSubtle, lineWidth: 1)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PrecisionTheme.recessedBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(PrecisionTheme.borderSubtle, lineWidth: 1)
        )
    }
}
