import SwiftUI
import UniformTypeIdentifiers
import AppKit

public enum NavigationTab: String, CaseIterable, Identifiable {
    case queue = "Queue & Resize"
    case presets = "Batch Presets"
    case outputSettings = "Output Settings"
    case history = "History"

    public var id: String { rawValue }
}

public struct MainView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var presetStore = PresetStore.shared
    @StateObject private var batchService = BatchResizeService.shared

    @State private var selectedTab: NavigationTab = .queue
    @State private var items: [ImageItem] = []
    @State private var isTargetedForDrop: Bool = false
    @State private var sessionID: String = "BatchSession_\(String(format: "%04d", Int.random(in: 1000...9999)))"

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
        let count = items.count
        let origBytes = items.reduce(0) { $0 + $1.fileSize }
        guard count > 0, origBytes > 0 else {
            return (0, "0 B", "0 B", 0.0)
        }

        var estTotal: Int64 = 0
        for item in items {
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
                    if items.isEmpty {
                        EmptyDropZoneView(onSelectFiles: openFilePicker)
                    } else {
                        HSplitView {
                            // Queue View (7-col weight)
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
                            .frame(minWidth: 420, maxWidth: .infinity)

                            // Resize Settings Inspector (5-col weight)
                            ResizeSettingsView(
                                configuration: $appSettings.configuration,
                                sampleItem: items.first,
                                queueCount: items.count,
                                isProcessing: batchService.isProcessing,
                                onStartResize: startBatchResize,
                                onEditPresets: {
                                    selectedTab = .presets
                                }
                            )
                            .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
                        }
                    }

                case .presets:
                    PresetManagerView()

                case .outputSettings:
                    OutputSettingsView(configuration: $appSettings.configuration)

                case .history:
                    BatchHistoryResultsView(
                        result: batchService.lastResult,
                        onResizeAnother: {
                            selectedTab = .queue
                        }
                    )
                }

                // Drag overlay when dragging files into window
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
                            .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openImagesNotification)) { notification in
            if let urls = notification.object as? [URL] {
                self.addURLs(urls)
            }
        }
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

            // Right: Session pill & Quick Actions
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(PrecisionTheme.green)
                        .frame(width: 6, height: 6)

                    Text(sessionID)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(PrecisionTheme.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(PrecisionTheme.recessedBackground)
                .cornerRadius(5)

                Button(action: openFilePicker) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(PrecisionTheme.blue)
                        .frame(width: 26, height: 26)
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
                    .fill(batchService.isProcessing ? PrecisionTheme.blue : PrecisionTheme.green)
                    .frame(width: 7, height: 7)

                Text(batchService.isProcessing ? "Processing…" : "Ready")
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
                Text("\(queueStats.count) images (\(queueStats.formattedOrig))")
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
                selectedTab = .outputSettings
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

            // Acceleration Indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(PrecisionTheme.blue)
                    .frame(width: 5, height: 5)

                Text("Metal vImage GPU")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textSecondary)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(PrecisionTheme.cardBackground)
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
            if !items.contains(where: { $0.url.path == url.path }) {
                if let newItem = fileService.createImageItem(from: url) {
                    items.append(newItem)
                }
            }
        }
        if !urls.isEmpty && selectedTab != .queue {
            selectedTab = .queue
        }
    }

    private func startBatchResize() {
        guard !items.isEmpty else { return }

        batchService.resizeBatch(
            items: items,
            configuration: appSettings.configuration,
            preset: selectedPreset
        ) { result in
            // When complete, switch to History tab to see results!
            DispatchQueue.main.async {
                self.selectedTab = .history
            }
        }
    }
}
