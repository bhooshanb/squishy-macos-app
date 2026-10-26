import SwiftUI
import AppKit

public struct ResizeSettingsView: View {
    @Binding public var configuration: ResizeConfiguration
    @ObservedObject public var presetStore = PresetStore.shared
    public let sampleItem: ImageItem?
    public let queueCount: Int
    public let isProcessing: Bool
    public let onStartResize: () -> Void

    @State private var showPresetManager: Bool = false

    public init(
        configuration: Binding<ResizeConfiguration>,
        sampleItem: ImageItem?,
        queueCount: Int,
        isProcessing: Bool,
        onStartResize: @escaping () -> Void
    ) {
        self._configuration = configuration
        self.sampleItem = sampleItem
        self.queueCount = queueCount
        self.isProcessing = isProcessing
        self.onStartResize = onStartResize
    }

    private var activePreset: ResizePreset? {
        presetStore.preset(for: configuration.selectedPresetId) ?? presetStore.presets.first
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Section 1: Resize Mode & Dimensions
                modeAndDimensionsCard

                // Section 2: Output Format & Quality
                formatAndQualityCard

                // Section 3: File Destination & Naming
                destinationAndNamingCard

                // Section 4: Live Preview & Action
                actionCard
            }
            .padding(16)
        }
        .frame(minWidth: 280, idealWidth: 340, maxWidth: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showPresetManager) {
            PresetManagerSheet()
        }
    }

    // MARK: - Dimension Settings Card

    private var modeAndDimensionsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Resize Mode")
                        .font(.headline)
                    Spacer()
                    AspectRatioLockIndicator()
                }

                Picker("Mode", selection: Binding(
                    get: { configuration.mode },
                    set: { newMode in
                        let oldMode = configuration.mode
                        guard oldMode != newMode else { return }
                        ImageResizeEngine.adaptConfigurationOnModeChange(
                            configuration: &configuration,
                            from: oldMode,
                            to: newMode,
                            preset: activePreset,
                            availablePresets: presetStore.presets,
                            sampleOriginal: sampleItem?.originalDimensions
                        )
                        configuration.mode = newMode
                    }
                )) {
                    ForEach(ResizeMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.systemImageName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // Common & Social Media Aspect Ratio Quick Selector
                aspectRatioPillsSection

                switch configuration.mode {
                case .preset:
                    presetControls

                case .fit:
                    customFitControls

                case .widthOnly:
                    widthOnlyControls

                case .heightOnly:
                    heightOnlyControls

                case .percentage:
                    percentageControls
                }

                Divider()

                Toggle(isOn: $configuration.allowUpscaling) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow upscaling")
                            .font(.system(size: 13, weight: .medium))
                        Text("When disabled, images smaller than the target dimensions will not be enlarged.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    private var presetControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Preset", selection: $configuration.selectedPresetId) {
                    ForEach(presetStore.presets) { preset in
                        Text("\(preset.name) (\(preset.maxWidth) × \(preset.maxHeight))")
                            .tag(preset.id)
                    }
                }
                .pickerStyle(.menu)

                Button(action: {
                    showPresetManager = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                .help("Manage custom presets")
            }

            if let preset = activePreset {
                Text("Images fit within a maximum \(preset.maxWidth) × \(preset.maxHeight) box without distortion.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var customFitControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Maximum Bounding Dimensions")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Width")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Width", value: $configuration.customWidth, format: .number)
                        .textFieldStyle(.roundedBorder)
                }

                Button(action: swapCustomDimensions) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accentColor)
                        .frame(width: 26, height: 26)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Swap Width & Height (Landscape ⇄ Portrait)")
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Height")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Height", value: $configuration.customHeight, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Text("Image will scale to fit inside this box while strictly preserving aspect ratio.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var widthOnlyControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Target Width (px)")
                .font(.caption2)
                .foregroundColor(.secondary)
            TextField("Width", value: $configuration.customWidth, format: .number)
                .textFieldStyle(.roundedBorder)
            Text("Height will be calculated automatically to preserve the aspect ratio.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var heightOnlyControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Target Height (px)")
                .font(.caption2)
                .foregroundColor(.secondary)
            TextField("Height", value: $configuration.customHeight, format: .number)
                .textFieldStyle(.roundedBorder)
            Text("Width will be calculated automatically to preserve the aspect ratio.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var percentageControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scale Factor")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(configuration.percentage))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }

            Slider(value: $configuration.percentage, in: 10...300, step: 5)

            HStack(spacing: 6) {
                quickPercentButton(25)
                quickPercentButton(50)
                quickPercentButton(75)
                quickPercentButton(100)
                quickPercentButton(150)
                quickPercentButton(200)
            }
        }
    }

    private func quickPercentButton(_ value: Double) -> some View {
        Button("\(Int(value))%") {
            configuration.percentage = value
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }

    // MARK: - Format & Quality Card

    private var formatAndQualityCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Format & Quality")
                    .font(.headline)

                Picker("Output Format", selection: $configuration.outputFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)

                if configuration.outputFormat.supportsQuality {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Quality")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(configuration.quality * 100))%")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $configuration.quality, in: 0.1...1.0, step: 0.05)
                    }
                }

                Toggle("Preserve metadata (EXIF, color profiles)", isOn: $configuration.preserveMetadata)
                    .font(.caption)
                    .toggleStyle(.checkbox)
            }
        }
    }

    // MARK: - Destination & Naming Card

    private var destinationAndNamingCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("File Management")
                    .font(.headline)

                Picker("Destination", selection: $configuration.destinationMode) {
                    ForEach(OutputDestinationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                if configuration.destinationMode == .subfolder {
                    HStack {
                        Text("Subfolder:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Subfolder Name", text: $configuration.subfolderName)
                            .textFieldStyle(.roundedBorder)
                    }
                } else if configuration.destinationMode == .customFolder {
                    HStack {
                        Text(configuration.customDestinationPath ?? "No folder selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Browse…") {
                            chooseCustomFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                HStack {
                    Text("Filename Suffix:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Suffix", text: $configuration.filenameSuffix)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Append preset name to filename", isOn: $configuration.appendPresetNameToFilename)
                    .font(.caption)
                    .toggleStyle(.checkbox)

                Picker("If file exists", selection: $configuration.collisionHandling) {
                    ForEach(CollisionHandling.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)

                Divider()

                liveFilenamePreview
            }
        }
    }

    // MARK: - Action Card

    private var actionCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                if let sample = sampleItem {
                    let calculated = ImageResizeEngine.calculateDimensions(
                        original: sample.originalDimensions,
                        mode: configuration.mode,
                        targetWidth: configuration.customWidth,
                        targetHeight: configuration.customHeight,
                        percentage: configuration.percentage,
                        preset: activePreset,
                        allowUpscaling: configuration.allowUpscaling
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dimension Preview")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        HStack {
                            Text(sample.originalDimensions.description)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)

                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)

                            Text(calculated.description)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.accentColor)
                        }
                    }

                    Divider()
                }

                Button(action: onStartResize) {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                        }

                        Text(queueCount > 0 ? "Resize \(queueCount) \(queueCount == 1 ? "Image" : "Images")" : "Resize Images")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(queueCount == 0 || isProcessing)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Destination Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            configuration.customDestinationPath = url.path
        }
    }

    // MARK: - Aspect Ratio Pills Section

    private var aspectRatioPillsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Popular & Social Media Ratios")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let active = activeAspectRatioPreset {
                    Text(active.subtitle)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AspectRatioPreset.all) { preset in
                        let selected = isAspectRatioSelected(preset)
                        Button(action: {
                            applyAspectRatio(preset)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(preset.name)
                                        .font(.system(size: 11, weight: .medium))
                                    Text(preset.ratioLabel)
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(selected ? .white.opacity(0.85) : .secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                            .foregroundColor(selected ? .white : .primary)
                            .cornerRadius(7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("\(preset.name) (\(preset.ratioLabel)) — \(preset.width) × \(preset.height) px. \(preset.subtitle)")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var activeAspectRatioPreset: AspectRatioPreset? {
        AspectRatioPreset.all.first(where: { isAspectRatioSelected($0) })
    }

    private func isAspectRatioSelected(_ preset: AspectRatioPreset) -> Bool {
        if configuration.mode == .fit {
            if configuration.customWidth == preset.width && configuration.customHeight == preset.height {
                return true
            }
            let currentRatio = Double(configuration.customWidth) / Double(max(1, configuration.customHeight))
            let targetRatio = Double(preset.width) / Double(preset.height)
            return abs(currentRatio - targetRatio) < 0.02
        }
        return false
    }

    private func applyAspectRatio(_ preset: AspectRatioPreset) {
        configuration.mode = .fit
        configuration.customWidth = preset.width
        configuration.customHeight = preset.height
    }

    private func swapCustomDimensions() {
        let temp = configuration.customWidth
        configuration.customWidth = configuration.customHeight
        configuration.customHeight = temp
    }

    // MARK: - Live Filename Preview

    private var liveFilenamePreview: some View {
        let sampleName = sampleItem?.filename ?? "photo.jpg"
        let base = (sampleName as NSString).deletingPathExtension
        let ext = configuration.outputFormat == .original
            ? (sampleItem?.url.pathExtension ?? "jpg")
            : configuration.outputFormat.fileExtension

        var suffix = configuration.filenameSuffix
        if configuration.appendPresetNameToFilename, let preset = activePreset {
            suffix += "_\(preset.name.replacingOccurrences(of: " ", with: "_"))"
        }

        let folder = configuration.destinationMode == .subfolder
            ? (configuration.subfolderName.isEmpty ? "Resized/" : "\(configuration.subfolderName)/")
            : ""

        let previewText = "\(sampleName) ➔ \(folder)\(base)\(suffix).\(ext)"

        return VStack(alignment: .leading, spacing: 3) {
            Text("Preview Result")
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(previewText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
}
