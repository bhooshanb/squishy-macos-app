import SwiftUI
import UniformTypeIdentifiers

public struct MainView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var presetStore = PresetStore.shared
    @StateObject private var batchService = BatchResizeService.shared

    @State private var items: [ImageItem] = []
    @State private var isTargetedForDrop: Bool = false
    @State private var showResultsSheet: Bool = false

    private let fileService = ImageFileService.shared

    public init() {}

    private var selectedPreset: ResizePreset? {
        presetStore.preset(for: appSettings.configuration.selectedPresetId) ?? presetStore.presets.first
    }

    public var body: some View {
        ZStack {
            if items.isEmpty {
                EmptyDropZoneView(onSelectFiles: openFilePicker)
            } else {
                HSplitView {
                    // Queue View
                    ImageQueueView(
                        items: $items,
                        configuration: appSettings.configuration,
                        selectedPreset: selectedPreset,
                        onAddMore: openFilePicker,
                        onClearAll: {
                            items.removeAll()
                            batchService.lastResult = nil
                        }
                    )
                    .frame(minWidth: 350, maxWidth: .infinity)

                    // Settings View
                    ResizeSettingsView(
                        configuration: $appSettings.configuration,
                        sampleItem: items.first,
                        queueCount: items.count,
                        isProcessing: batchService.isProcessing,
                        onStartResize: startBatchResize
                    )
                    .frame(minWidth: 280, idealWidth: 340, maxWidth: .infinity)
                }
            }

            // Drag overlay when hovering over the window
            if isTargetedForDrop {
                DropOverlayView()
            }

            // Floating progress banner during processing
            if batchService.isProcessing {
                VStack {
                    Spacer()
                    BatchProgressView(batchService: batchService)
                        .padding(20)
                        .frame(maxWidth: 550)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Floating results banner upon completion
            if let result = batchService.lastResult, !batchService.isProcessing {
                VStack {
                    Spacer()
                    ResizeResultsView(
                        result: result,
                        onDismiss: {
                            batchService.lastResult = nil
                        }
                    )
                    .padding(20)
                    .frame(maxWidth: 550)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 780, minHeight: 520)
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openImagesNotification)) { notification in
            if let urls = notification.object as? [URL] {
                self.addURLs(urls)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: openFilePicker) {
                    Label("Add Images", systemImage: "plus")
                }
                .help("Add images to resize (⌘O)")

                if !items.isEmpty {
                    Button(role: .destructive, action: { items.removeAll() }) {
                        Label("Clear Queue", systemImage: "trash")
                    }
                    .help("Clear all images from queue")
                }
            }
        }
    }

    // MARK: - Actions

    private func openFilePicker() {
        let urls = fileService.selectFilesWithOpenPanel(allowsMultiple: true)
        addURLs(urls)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var foundURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    foundURLs.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let collected = fileService.collectImageURLs(from: foundURLs)
            self.addURLs(collected)
        }

        return true
    }

    private func addURLs(_ urls: [URL]) {
        for url in urls {
            // Avoid duplicate URLs in the queue
            if !items.contains(where: { $0.url.path == url.path }) {
                if let newItem = fileService.createImageItem(from: url) {
                    items.append(newItem)
                }
            }
        }
    }

    private func startBatchResize() {
        guard !items.isEmpty else { return }

        batchService.resizeBatch(
            items: items,
            configuration: appSettings.configuration,
            preset: selectedPreset
        ) { result in
            // Completion handled reactively via batchService.lastResult
        }
    }
}
