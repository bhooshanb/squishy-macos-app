import SwiftUI
import AppKit

public struct BatchHistoryResultsView: View {
    public let result: BatchResizeResult?
    public let onResizeAnother: () -> Void

    public init(result: BatchResizeResult?, onResizeAnother: @escaping () -> Void) {
        self.result = result
        self.onResizeAnother = onResizeAnother
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let res = result {
                    // Top Completion Banner
                    completionBanner(result: res)

                    // Results Queue Table
                    resultsQueueTable(result: res)
                } else {
                    emptyStateView
                }
            }
            .padding(20)
        }
        .background(PrecisionTheme.background)
    }

    // MARK: - Completion Banner
    private func completionBanner(result: BatchResizeResult) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(result.failedCount == 0 ? PrecisionTheme.greenLight : Color.orange.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: result.failedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(result.failedCount == 0 ? PrecisionTheme.green : .orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(result.failedCount == 0 ? "Batch Completed" : "Completed with Warnings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(PrecisionTheme.textPrimary)

                    Text("•")
                        .foregroundColor(PrecisionTheme.textTertiary)

                    Text("\(result.succeededCount) of \(result.totalCount) processed in \(String(format: "%.2fs", result.duration))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(PrecisionTheme.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PrecisionTheme.greenLight)
                        .cornerRadius(4)
                }

                HStack(spacing: 8) {
                    Text("Total Exported:")
                        .font(.system(size: 11))
                        .foregroundColor(PrecisionTheme.textSecondary)

                    Text("\(result.outputURLs.count) files")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(PrecisionTheme.textPrimary)

                    if result.failedCount > 0 {
                        Text("• \(result.failedCount) failed")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(PrecisionTheme.danger)
                    }
                }
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                Button(action: onResizeAnother) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("Resize Another Batch")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PrecisionTheme.cardBackground)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(PrecisionTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if let dir = result.destinationDirectory {
                    Button(action: {
                        revealInFinder(url: dir)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                            Text("Reveal in Finder")
                                .font(.system(size: 12, weight: .semibold))
                            ShortcutBadge("⌘O")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PrecisionTheme.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(PrecisionTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PrecisionTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Results Queue Table
    private func resultsQueueTable(result: BatchResizeResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Processed Output Files")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PrecisionTheme.textPrimary)

                Spacer()

                Text("\(result.outputURLs.count) files")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(PrecisionTheme.recessedBackground)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PrecisionTheme.cardHeaderBackground)

            Divider().background(PrecisionTheme.border)

            LazyVStack(spacing: 0) {
                ForEach(Array(result.outputURLs.enumerated()), id: \.element) { index, url in
                    HStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundColor(PrecisionTheme.blue)
                            .frame(width: 32, height: 32)
                            .background(PrecisionTheme.blueLight)
                            .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(PrecisionTheme.textPrimary)

                            Text(url.path)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundColor(PrecisionTheme.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }) {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 13))
                                .foregroundColor(PrecisionTheme.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Show in Finder")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if index < result.outputURLs.count - 1 {
                        Divider().background(PrecisionTheme.borderSubtle).padding(.horizontal, 12)
                    }
                }

                // If there were any errors
                if !result.errors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Processing Errors")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(PrecisionTheme.danger)

                        ForEach(Array(result.errors.enumerated()), id: \.offset) { _, err in
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(PrecisionTheme.danger)
                                    .font(.system(size: 11))
                                Text("\(err.filename): \(err.message)")
                                    .font(.system(size: 11))
                                    .foregroundColor(PrecisionTheme.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PrecisionTheme.dangerLight)
                }
            }
        }
        .background(PrecisionTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PrecisionTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundColor(PrecisionTheme.textTertiary)

            Text("No Recent Batch Runs")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(PrecisionTheme.textPrimary)

            Text("Resize images in the Queue & Resize tab to view export statistics and outputs here.")
                .font(.system(size: 12))
                .foregroundColor(PrecisionTheme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func revealInFinder(url: URL) {
        if let firstOutput = result?.outputURLs.first {
            NSWorkspace.shared.activateFileViewerSelecting([firstOutput])
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
