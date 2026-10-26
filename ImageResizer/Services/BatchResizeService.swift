import Foundation
import AppKit

public final class BatchResizeService: ObservableObject, @unchecked Sendable {
    public static let shared = BatchResizeService()

    @Published public var isProcessing: Bool = false
    @Published public var totalItems: Int = 0
    @Published public var processedItems: Int = 0
    @Published public var currentFilename: String = ""
    @Published public var progressFraction: Double = 0.0
    @Published public var lastResult: BatchResizeResult?

    private var activeTask: Task<Void, Never>?
    private let engine = ImageResizeEngine.shared
    private let outputManager = OutputManager.shared

    public init() {}

    /// Cancels any currently executing batch resize
    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
        DispatchQueue.main.async {
            self.isProcessing = false
        }
    }

    /// Resizes an array of ImageItems concurrently with memory-controlled concurrency
    public func resizeBatch(
        items: [ImageItem],
        configuration: ResizeConfiguration,
        preset: ResizePreset?,
        onComplete: @escaping @MainActor (BatchResizeResult) -> Void
    ) {
        guard !items.isEmpty else { return }

        cancel()

        isProcessing = true
        totalItems = items.count
        processedItems = 0
        progressFraction = 0.0
        currentFilename = ""
        lastResult = nil

        let startTime = Date()
        let concurrencyLimit = max(1, min(ProcessInfo.processInfo.activeProcessorCount, 4))

        activeTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            var succeededURLs: [URL] = []
            var errors: [(filename: String, message: String)] = []
            var lastDestinationDir: URL?

            // Concurrency-limited processing via async channel / iterator
            await withTaskGroup(of: (item: ImageItem, result: Result<URL, Error>).self) { group in
                var itemIndex = 0

                // Seed initial workers up to concurrency limit
                while itemIndex < items.count && itemIndex < concurrencyLimit {
                    let item = items[itemIndex]
                    itemIndex += 1

                    group.addTask {
                        let res = await self.processSingleItem(item: item, configuration: configuration, preset: preset)
                        return (item, res)
                    }
                }

                // Process completions and feed remaining items
                for await (item, result) in group {
                    if Task.isCancelled { break }

                    switch result {
                    case .success(let outputURL):
                        succeededURLs.append(outputURL)
                        lastDestinationDir = outputURL.deletingLastPathComponent()

                        await MainActor.run {
                            self.processedItems += 1
                            self.progressFraction = Double(self.processedItems) / Double(self.totalItems)
                            self.currentFilename = item.filename
                            item.status = .succeeded(outputURL: outputURL)
                        }

                    case .failure(let error):
                        errors.append((filename: item.filename, message: error.localizedDescription))

                        await MainActor.run {
                            self.processedItems += 1
                            self.progressFraction = Double(self.processedItems) / Double(self.totalItems)
                            self.currentFilename = item.filename
                            item.status = .failed(errorDescription: error.localizedDescription)
                        }
                    }

                    // Feed next task if available
                    if itemIndex < items.count && !Task.isCancelled {
                        let nextItem = items[itemIndex]
                        itemIndex += 1

                        group.addTask {
                            let res = await self.processSingleItem(item: nextItem, configuration: configuration, preset: preset)
                            return (nextItem, res)
                        }
                    }
                }
            }

            let duration = Date().timeIntervalSince(startTime)
            let finalResult = BatchResizeResult(
                totalCount: items.count,
                succeededCount: succeededURLs.count,
                failedCount: errors.count,
                outputURLs: succeededURLs,
                errors: errors,
                destinationDirectory: lastDestinationDir,
                duration: duration
            )

            await MainActor.run {
                self.isProcessing = false
                self.lastResult = finalResult
                onComplete(finalResult)
            }
        }
    }

    private func processSingleItem(
        item: ImageItem,
        configuration: ResizeConfiguration,
        preset: ResizePreset?
    ) async -> Result<URL, Error> {
        await MainActor.run {
            item.status = .processing
        }

        do {
            // 1. Calculate dimensions for this individual image
            let targetDimensions = ImageResizeEngine.calculateDimensions(
                original: item.originalDimensions,
                mode: configuration.mode,
                targetWidth: configuration.customWidth,
                targetHeight: configuration.customHeight,
                percentage: configuration.percentage,
                preset: preset,
                allowUpscaling: configuration.allowUpscaling
            )

            await MainActor.run {
                item.outputDimensions = targetDimensions
            }

            // 2. Resolve destination path
            let destinationURL = try outputManager.resolveDestinationURL(
                for: item.url,
                configuration: configuration,
                presetName: preset?.name
            )

            // 3. Perform image resize
            try engine.resizeImage(
                from: item.url,
                to: destinationURL,
                targetDimensions: targetDimensions,
                outputFormat: configuration.outputFormat,
                quality: configuration.quality,
                preserveMetadata: configuration.preserveMetadata
            )

            return .success(destinationURL)
        } catch {
            return .failure(error)
        }
    }
}
