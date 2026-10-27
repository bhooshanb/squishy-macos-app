import SwiftUI

public struct ImageQueueView: View {
    @Binding public var items: [ImageItem]
    public let configuration: ResizeConfiguration
    public let selectedPreset: ResizePreset?
    public let onAddMore: () -> Void
    public let onClearAll: () -> Void

    public init(
        items: Binding<[ImageItem]>,
        configuration: ResizeConfiguration,
        selectedPreset: ResizePreset?,
        onAddMore: @escaping () -> Void,
        onClearAll: @escaping () -> Void
    ) {
        self._items = items
        self.configuration = configuration
        self.selectedPreset = selectedPreset
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
            // DropZone & Queue Header Card
            queueHeaderCard

            // macOS File List Table Card
            fileListTableCard

            // Hardware & Engine Callout Bar
            hardwareCalloutBar
        }
        .padding(16)
        .background(PrecisionTheme.background)
    }

    // MARK: - Queue Header Card
    private var queueHeaderCard: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(PrecisionTheme.blueLight)
                    .frame(width: 36, height: 36)

                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PrecisionTheme.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Processing Queue")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PrecisionTheme.textPrimary)

                    StatusPill(title: "\(items.count) ready", isPositive: true)
                }

                Text("Drag & drop images anywhere or press ⌘O")
                    .font(.system(size: 11))
                    .foregroundColor(PrecisionTheme.textTertiary)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                Button(action: onAddMore) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(PrecisionTheme.blue)
                        Text("Add Files")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PrecisionTheme.cardBackground)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(PrecisionTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if !items.isEmpty {
                    Button(action: onClearAll) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Clear")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(PrecisionTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all images from queue")
                }
            }
        }
        .padding(12)
        .background(PrecisionTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(PrecisionTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
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
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let targetDimensions = ImageResizeEngine.calculateDimensions(
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
                            }
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

            Text("Apple Silicon Metal acceleration ready • Lanczos bicubic resampling")
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
