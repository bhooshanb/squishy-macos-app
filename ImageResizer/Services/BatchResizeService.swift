import Foundation
import AppKit

public final class BatchResizeService: ObservableObject, @unchecked Sendable {
    public static let shared = BatchResizeService()

    @Published public var isProcessing: Bool = false
    @Published public var isPaused: Bool = false
    @Published public private(set) var wasStopped: Bool = false
    @Published public var totalItems: Int = 0
    @Published public var processedItems: Int = 0
    @Published public var currentFilename: String = ""
    @Published public var progressFraction: Double = 0.0
    @Published public var lastResult: BatchResizeResult?

    private var activeTask: Task<Void, Never>?
    private let processingControl = BatchProcessingControl()
    private let engine = ImageResizeEngine.shared
    private let outputManager = OutputManager.shared
    private let videoEngine = VideoCompressionEngine.shared

    public init() {}

    /// Cancels any currently executing batch resize
    public func cancel() {
        stop()
    }

    public func pause() {
        guard isProcessing else { return }
        processingControl.pause()
        isPaused = true
    }

    public func resume() {
        guard isProcessing, isPaused else { return }
        processingControl.resume()
        isPaused = false
    }

    /// Stops after currently running files finish, leaving not-yet-started files idle in the queue.
    public func stop() {
        processingControl.stop()
        isPaused = false
        wasStopped = true
    }

    private func waitWhilePaused() -> Bool {
        processingControl.waitUntilRunning()
    }

    private func canScheduleMore() -> Bool {
        !processingControl.isStopped()
    }

    /// Resizes an array of ImageItems concurrently with memory-controlled concurrency
    public func resizeBatch(
        items: [ImageItem],
        configuration: ResizeConfiguration,
        preset: ResizePreset?,
        onComplete: @escaping @MainActor (BatchResizeResult) -> Void
    ) {
        let items = items.filter { !$0.status.isSuccess }
        guard !items.isEmpty, !isProcessing else { return }

        isProcessing = true
        isPaused = false
        wasStopped = false
        processingControl.reset()
        totalItems = items.count
        processedItems = 0
        progressFraction = 0.0
        currentFilename = ""
        lastResult = nil

        let startTime = Date()
        // One active item makes Pause/Stop deterministic: no additional file starts while the
        // current item is being paused or stopped.
        let concurrencyLimit = 1

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
                    if !self.waitWhilePaused() { break }
                    let item = items[itemIndex]
                    itemIndex += 1

                    group.addTask {
                        let res = await self.processSingleItem(item: item, configuration: configuration, preset: preset)
                        return (item, res)
                    }
                }

                // Process completions and feed remaining items
                for await (item, result) in group {
                    if Task.isCancelled { group.cancelAll(); break }

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
                        if error is CancellationError, self.processingControl.isStopped() {
                            await MainActor.run { item.status = .idle }
                        } else {
                            errors.append((filename: item.filename, message: error.localizedDescription))
                            await MainActor.run {
                                self.processedItems += 1
                                self.progressFraction = Double(self.processedItems) / Double(self.totalItems)
                                self.currentFilename = item.filename
                                item.status = .failed(errorDescription: error.localizedDescription)
                            }
                        }
                    }


                    // Feed next task if available
                    _ = self.waitWhilePaused()
                    let shouldScheduleNext = self.canScheduleMore()
                    if itemIndex < items.count && !Task.isCancelled && shouldScheduleNext {
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
                self.isPaused = false
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
            if item.mediaKind == .video {
                let destinationURL = try outputManager.resolveDestinationURL(for: item.url, configuration: configuration, presetName: preset?.name, forceExtension: "mp4")
                try await videoEngine.compress(from: item.url, to: destinationURL, outputBitrate: configuration.videoBitratePreset.bitsPerSecond, control: processingControl)
                return .success(destinationURL)
            }

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
                preserveMetadata: configuration.preserveMetadata,
                preserveFileTimestamps: configuration.preserveFileTimestamps
            )

            return .success(destinationURL)
        } catch {
            return .failure(error)
        }
    }
}
