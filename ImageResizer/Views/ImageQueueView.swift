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

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("\(items.count) \(items.count == 1 ? "image" : "images") selected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onAddMore) {
                    Label("Add Images", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive, action: onClearAll) {
                    Label("Clear All", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // List of images
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(items) { item in
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
                                if let index = items.firstIndex(where: { $0.id == item.id }) {
                                    items.remove(at: index)
                                }
                            }
                        )
                    }
                }
                .padding(12)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}
