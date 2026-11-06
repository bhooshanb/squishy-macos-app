import SwiftUI
import AppKit

public struct ResizeResultsView: View {
    public let result: BatchResizeResult
    public let onDismiss: () -> Void

    @State private var showErrors: Bool = false

    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(result.failedCount == 0 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: result.failedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(result.failedCount == 0 ? .green : .orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.failedCount == 0 ? "Batch Complete" : "Completed with Issues")
                        .font(.headline)

                    HStack(spacing: 6) {
                        Text("\(result.succeededCount) of \(result.totalCount) succeeded")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary.opacity(0.6))

                        Text(String(format: "%.1fs", result.duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if let dir = result.destinationDirectory {
                        Button(action: {
                            revealInFinder(url: dir)
                        }) {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Done") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // Error summary list if any
            if !result.errors.isEmpty {
                DisclosureGroup(
                    isExpanded: $showErrors,
                    content: {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(result.errors.enumerated()), id: \.offset) { _, error in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text("\(error.filename): \(error.message)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 6)
                    },
                    label: {
                        Text("\(result.failedCount) file(s) could not be resized")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.red)
                    }
                )
            }
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private func revealInFinder(url: URL) {
        if let firstOutput = result.outputURLs.first {
            NSWorkspace.shared.activateFileViewerSelecting([firstOutput])
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
