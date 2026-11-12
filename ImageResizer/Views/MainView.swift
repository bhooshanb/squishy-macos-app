import SwiftUI
import UniformTypeIdentifiers
import AppKit

public enum NavigationTab: String, CaseIterable, Identifiable {
    case queue = "Queue & Resize"
    case settings = "Settings"
    case history = "History"

    public var id: String { rawValue }
}

private enum MediaQueueFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case images = "Images"
    case videos = "Videos"
    var id: String { rawValue }
}

public struct MainView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var presetStore = PresetStore.shared
    @StateObject private var imageBatchService = BatchResizeService()
    @StateObject private var videoBatchService = BatchResizeService()

    @State private var selectedTab: NavigationTab = .queue
    @State private var imageItems: [ImageItem] = []
    @State private var videoItems: [ImageItem] = []
    @State private var isTargetedForDrop: Bool = false
    @State private var queueFilter: MediaQueueFilter = .all
    @State private var clearedQueueSnapshot: ([ImageItem], [ImageItem])?

    private let fileService = ImageFileService.shared

    public init() {}

    private var selectedPreset: ResizePreset? {
        presetStore.preset(for: appSettings.configuration.selectedPresetId) ?? presetStore.presets.first
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(version)"
    }

    private var queueStats: (count: Int, formattedOrig: String, formattedSaving: String, percentSaving: Double) {
        let allItems = imageItems + videoItems
        let count = allItems.count
        let origBytes = allItems.reduce(0) { $0 + $1.fileSize }
        guard count > 0, origBytes > 0 else {
            return (0, "0 B", "0 B", 0.0)
        }

        var estTotal: Int64 = 0
        for item in allItems {
            if item.mediaKind == .video {
                let outputBitrate = min(appSettings.configuration.videoBitratePreset.bitsPerSecond, item.sourceVideoBitrate ?? appSettings.configuration.videoBitratePreset.bitsPerSecond)
                let inputBitrate = max(1, item.sourceVideoBitrate ?? outputBitrate)
                estTotal += Int64(Double(item.fileSize) * Double(outputBitrate) / Double(inputBitrate))
                continue
            }
            let target = ImageResizeEngine.calculateDimensions(
                original: item.originalDimensions,
                mode: appSettings.configuration.mode,
                targetWidth: appSettings.configuration.customWidth,
                targetHeight: appSettings.configuration.customHeight,
                percentage: appSettings.configuration.percentage,
                preset: selectedPreset,
                allowUpscaling: appSettings.configuration.allowUpscaling
            )
            if item.originalDimensions.width > 0 && item.originalDimensions.height > 0 {
                let origArea = Double(item.originalDimensions.width * item.originalDimensions.height)
                let targetArea = Double(target.width * target.height)
                let ratio = min(1.0, max(0.05, targetArea / origArea))
                estTotal += Int64(Double(item.fileSize) * ratio)
            } else {
                estTotal += item.fileSize
            }
        }

        let saving = max(0, origBytes - estTotal)
        let percent = (Double(saving) / Double(origBytes)) * 100.0

        let formattedOrig = ByteCountFormatter.string(fromByteCount: origBytes, countStyle: .file)
        let formattedSaving = ByteCountFormatter.string(fromByteCount: saving, countStyle: .file)
        return (count, formattedOrig, formattedSaving, percent)
    }

    private var destinationDisplayPath: String {
        switch appSettings.configuration.destinationMode {
        case .subfolder:
            return "~/\(appSettings.configuration.subfolderName)"
        case .sameFolder:
            return "Alongside source files"
        case .customFolder:
            if let custom = appSettings.configuration.customDestinationPath, !custom.isEmpty {
                return (custom as NSString).abbreviatingWithTildeInPath
            }
            return "~/Pictures/Exports"
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // macOS Precision Window Header Bar
            headerNavigationBar

            Divider()
                .background(PrecisionTheme.border)

            // Main Tab Content
            ZStack {
                switch selectedTab {
                case .queue:
                    mediaQueuesView

                case .settings:
                    OutputSettingsView(configuration: $appSettings.configuration)

                case .history:
                    BatchHistoryResultsView(
                        result: imageBatchService.lastResult ?? videoBatchService.lastResult,
                        onResizeAnother: {
                            selectedTab = .queue
                        }
                    )
                }

                // Drag overlay when dragging files into window
                if isTargetedForDrop {
                    DropOverlayView()
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .background(PrecisionTheme.border)

            // Whisper-Quiet macOS Status Bar Footer
            statusBarFooter
        }
        .frame(minWidth: 840, minHeight: 560)
        .background(PrecisionTheme.background)
        .preferredColorScheme(appSettings.appearance.colorScheme)
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openImagesNotification)) { notification in
            if let urls = notification.object as? [URL] {
                self.addURLs(urls)
            }
        }
    }

    private var mediaQueuesView: some View {
        HSplitView {
            VStack(spacing: 10) {
                HStack {
                    Text("Processing Queue · \(imageItems.count + videoItems.count)")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Picker("", selection: $queueFilter) {
                        ForEach(MediaQueueFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize(horizontal: true, vertical: false)
                    Menu {
                        Button("Add Images…", action: openImagePicker)
                        Button("Add Videos…", action: openVideoPicker)
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    Button("Clear", action: clearAllQueues)
                        .disabled(imageItems.isEmpty && videoItems.isEmpty)
                    if clearedQueueSnapshot != nil {
                        Button("Undo") { undoClearQueues() }
                    }
                }
                .padding(.horizontal, 4)

                if imageItems.isEmpty && videoItems.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 28))
                            .foregroundStyle(PrecisionTheme.blue)
                        Text("Drop images or videos here")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Or use Add to choose files. Images and videos stay in their own processing workflows.")
                            .font(.system(size: 12))
                            .foregroundStyle(PrecisionTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PrecisionTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ImageQueueView(
                        items: filteredQueueBinding,
                        configuration: appSettings.configuration,
                        selectedPreset: selectedPreset,
                        isProcessing: imageBatchService.isProcessing || videoBatchService.isProcessing,
                        onAddMore: openImagePicker,
                        onClearAll: clearAllQueues
                    )
                }
            }
            .padding(12)
            .frame(minWidth: 420, maxWidth: .infinity)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Image settings")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                    ResizeSettingsView(configuration: $appSettings.configuration, sampleItem: imageItems.first, queueCount: imageItems.count, isProcessing: imageBatchService.isProcessing, onStartResize: startImageBatch, showsActionBar: false)
                }
                .frame(maxHeight: .infinity)
                if !videoItems.isEmpty || videoBatchService.isProcessing {
                    Divider()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Video settings")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                        ResizeSettingsView(configuration: $appSettings.configuration, sampleItem: videoItems.first, queueCount: videoItems.count, isProcessing: videoBatchService.isProcessing, onStartResize: startVideoBatch, showsActionBar: false, videoBitratePreset: $appSettings.configuration.videoBitratePreset)
                    }
                    .frame(maxHeight: .infinity)
                }
                Divider()
                unifiedActionFooter
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
        }
    }

    private var filteredQueueBinding: Binding<[ImageItem]> {
        Binding(
            get: {
                switch queueFilter {
                case .all: imageItems + videoItems
                case .images: imageItems
                case .videos: videoItems
                }
            },
            set: { updated in
                switch queueFilter {
                case .all:
                    imageItems = updated.filter { $0.mediaKind == .image }
                    videoItems = updated.filter { $0.mediaKind == .video }
                case .images: imageItems = updated
                case .videos: videoItems = updated
                }
            }
        )
    }

    private var unifiedActionFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated savings · \(queueStats.formattedSaving) (\(queueStats.percentSaving, specifier: "%.0f")%)")
                        .font(.system(size: 11, weight: .medium))
                    Button {
                        selectedTab = .settings
                    } label: {
                        Label("Save to \(destinationDisplayPath) · Originals are never modified", systemImage: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(PrecisionTheme.textSecondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .help("Change the destination folder in Settings")
                }
                Spacer(minLength: 0)
            }
            Button(action: startAllBatches) {
                Label("Compress \(imageItems.count + videoItems.count) Files", systemImage: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent)
            .disabled((imageItems.isEmpty && videoItems.isEmpty) || imageBatchService.isProcessing || videoBatchService.isProcessing)
            .keyboardShortcut(.return, modifiers: .command)

            queueControlRow(title: "Images", service: imageBatchService)
            if !videoItems.isEmpty || videoBatchService.isProcessing {
                queueControlRow(title: "Videos", service: videoBatchService)
            }
        }
        .padding(12)
        .background(PrecisionTheme.cardBackground)
    }

    @ViewBuilder
    private func queueControlRow(title: String, service: BatchResizeService) -> some View {
        if service.isProcessing {
            HStack {
                Text("\(title) · \(service.isPaused ? "Paused" : service.currentFilename)")
                    .font(.system(size: 10.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(service.isPaused ? "Resume" : "Pause", systemImage: service.isPaused ? "play.fill" : "pause.fill", action: service.isPaused ? service.resume : service.pause)
                Button("Stop", systemImage: "stop.fill", action: service.stop)
                    .tint(.red)
            }
        }
    }

    private func startAllBatches() {
        startImageBatch()
        startVideoBatch()
    }

    private func clearAllQueues() {
        guard !imageItems.isEmpty || !videoItems.isEmpty else { return }
        clearedQueueSnapshot = (imageItems, videoItems)
        clearImageQueue()
        clearVideoQueue()
    }

    private func undoClearQueues() {
        guard let snapshot = clearedQueueSnapshot else { return }
        imageItems = snapshot.0
        videoItems = snapshot.1
        for item in imageItems + videoItems { item.status = .idle }
        clearedQueueSnapshot = nil
    }

    // MARK: - Header Bar
    private var headerNavigationBar: some View {
        HStack(spacing: 12) {
            // Left: Brand Title & Version
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(PrecisionTheme.blue)
                        .frame(width: 24, height: 24)

                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("Squishy")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PrecisionTheme.textPrimary)

                    Text(appVersionString)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(PrecisionTheme.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(PrecisionTheme.recessedBackground)
                        .cornerRadius(4)
                }
            }

            Spacer()

            // Center: Segmented Navigation Pills
            HStack(spacing: 2) {
                ForEach(NavigationTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? PrecisionTheme.textPrimary : PrecisionTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(isSelected ? PrecisionTheme.cardBackground : Color.clear)
                            .cornerRadius(6)
                            .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 1, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(PrecisionTheme.recessedBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(PrecisionTheme.borderSubtle, lineWidth: 1)
            )

            Spacer()

            // Right: Quick Action
            HStack(spacing: 6) {
                Button(action: openFilePicker) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add Files")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundColor(PrecisionTheme.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(PrecisionTheme.cardBackground)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(PrecisionTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Add Images (⌘O)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(PrecisionTheme.cardBackground)
    }

    // MARK: - Status Bar Footer
    private var statusBarFooter: some View {
        HStack(spacing: 12) {
            // Status Dot & Label
            HStack(spacing: 6) {
                Circle()
                    .fill((imageBatchService.isProcessing || videoBatchService.isProcessing) ? PrecisionTheme.blue : PrecisionTheme.green)
                    .frame(width: 7, height: 7)

                Text((imageBatchService.isProcessing || videoBatchService.isProcessing) ? "Processing…" : "Ready")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textPrimary)
            }

            Rectangle()
                .fill(PrecisionTheme.border)
                .frame(width: 1, height: 12)

            // Selection Stats
            HStack(spacing: 4) {
                Text("Selected:")
                    .foregroundColor(PrecisionTheme.textTertiary)
                Text("\(queueStats.count) files (\(queueStats.formattedOrig))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(PrecisionTheme.textPrimary)
            }

            Rectangle()
                .fill(PrecisionTheme.border)
                .frame(width: 1, height: 12)

            // Estimated Saving
            HStack(spacing: 4) {
                Text("Estimated Saving:")
                    .foregroundColor(PrecisionTheme.textTertiary)
                Text("-\(queueStats.formattedSaving) (\(String(format: "%.1f%%", queueStats.percentSaving)))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(PrecisionTheme.green)
            }

            Spacer()

            // Output Folder Path
            Button(action: {
                selectedTab = .settings
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                    Text(destinationDisplayPath)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                }
                .foregroundColor(PrecisionTheme.textSecondary)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(PrecisionTheme.border)
                .frame(width: 1, height: 12)

        }
        .font(.system(size: 11))
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(PrecisionTheme.cardBackground)
    }

    // MARK: - Actions

    private func openImagePicker() { addURLs(fileService.selectFilesWithOpenPanel(allowsMultiple: true, kind: .image)) }
    private func openVideoPicker() { addURLs(fileService.selectFilesWithOpenPanel(allowsMultiple: true, kind: .video)) }

    private func openFilePicker() { openImagePicker() }

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

    @MainActor
    private func addURLs(_ urls: [URL]) {
        for url in urls {
            if fileService.isSupportedImage(url), !imageItems.contains(where: { $0.url.path == url.path }), let newItem = fileService.createMediaItem(from: url, kind: .image) { imageItems.append(newItem) }
            if fileService.isSupportedVideo(url), !videoItems.contains(where: { $0.url.path == url.path }) {
                Task { @MainActor in
                    guard let newItem = await fileService.createVideoItem(from: url),
                          !videoItems.contains(where: { $0.url.path == url.path }) else { return }
                    videoItems.append(newItem)
                }
            }
        }
        if !urls.isEmpty && selectedTab != .queue {
            selectedTab = .queue
        }
    }

    private func startBatchResize() {
        startImageBatch()
    }

    private func startImageBatch() {
        guard !imageItems.isEmpty else { return }

        imageBatchService.resizeBatch(
            items: imageItems,
            configuration: appSettings.configuration,
            preset: selectedPreset
        ) { _ in }
    }

    private func startVideoBatch() {
        guard !videoItems.isEmpty else { return }
        videoBatchService.resizeBatch(items: videoItems, configuration: appSettings.configuration, preset: nil) { _ in }
    }

    private func clearImageQueue() {
        if imageBatchService.isProcessing { imageBatchService.stop() }
        imageItems.removeAll()
        imageBatchService.lastResult = nil
    }

    private func clearVideoQueue() {
        if videoBatchService.isProcessing { videoBatchService.stop() }
        videoItems.removeAll()
        videoBatchService.lastResult = nil
    }
}
