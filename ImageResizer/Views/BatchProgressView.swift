import SwiftUI

public struct BatchProgressView: View {
    @ObservedObject public var batchService: BatchResizeService

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Resizing Images…")
                    .font(.headline)
                Spacer()
                Text("\(batchService.processedItems) of \(batchService.totalItems)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            ProgressView(value: batchService.progressFraction)
                .progressViewStyle(.linear)

            HStack {
                if !batchService.currentFilename.isEmpty {
                    Text("Processing: \(batchService.currentFilename)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button("Cancel") {
                    batchService.cancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}
