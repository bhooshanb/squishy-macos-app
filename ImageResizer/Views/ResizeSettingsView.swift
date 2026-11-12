import SwiftUI
import AppKit

public struct ResizeSettingsView: View {
    @Binding public var configuration: ResizeConfiguration
    @ObservedObject public var presetStore = PresetStore.shared
    public let sampleItem: ImageItem?
    public let queueCount: Int
    public let isProcessing: Bool
    public let isPaused: Bool
    public let progressFraction: Double
    public let currentFilename: String
    public let onStartResize: () -> Void
    public let showsActionBar: Bool
    public let onPause: () -> Void
    public let onResume: () -> Void
    public let onStop: () -> Void
    public let videoBitratePreset: Binding<VideoBitratePreset>?
    @State private var showPresetManager = false
    @State private var areRatiosInverted: Bool = false
    private var hasVideo: Bool { sampleItem?.mediaKind == .video }

    public init(
        configuration: Binding<ResizeConfiguration>,
        sampleItem: ImageItem?,
        queueCount: Int,
        isProcessing: Bool,
        onStartResize: @escaping () -> Void,
        showsActionBar: Bool = true,
        videoBitratePreset: Binding<VideoBitratePreset>? = nil,
        isPaused: Bool = false,
        progressFraction: Double = 0,
        currentFilename: String = "",
        onPause: @escaping () -> Void = {},
        onResume: @escaping () -> Void = {},
        onStop: @escaping () -> Void = {}
    ) {
        self._configuration = configuration
        self.sampleItem = sampleItem
        self.queueCount = queueCount
        self.isProcessing = isProcessing
        self.isPaused = isPaused
        self.progressFraction = progressFraction
        self.currentFilename = currentFilename
        self.onStartResize = onStartResize
        self.showsActionBar = showsActionBar
        self.onPause = onPause
        self.onResume = onResume
        self.onStop = onStop
        self.videoBitratePreset = videoBitratePreset
    }

    private var activePreset: ResizePreset? {
        presetStore.preset(for: configuration.selectedPresetId) ?? presetStore.presets.first
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !hasVideo { mainConfigurationCard }
                else { videoExportSettingsCard }

                // Format & Output Card
                if !hasVideo { formatAndOutputCard }
            }
            .padding(16)
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: .infinity)
        .background(PrecisionTheme.background)
        .sheet(isPresented: $showPresetManager) { PresetManagerSheet() }
    }

    private var videoExportSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VIDEO EXPORT · MP4 / H.264")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PrecisionTheme.textTertiary)
            HStack {
                Text("Output bitrate").font(.system(size: 12, weight: .medium))
                Spacer()
                if let videoBitratePreset {
                    Picker("", selection: videoBitratePreset) {
                        ForEach(VideoBitratePreset.allCases) { preset in Text(preset.displayName).tag(preset) }
                    }
                    .pickerStyle(.menu)
                }
            }
            if showsActionBar { bottomActionBar }
        }
        .padding(14)
        .background(PrecisionTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Main Configuration Card
    private var mainConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Scaling Mode Header
            HStack {
                Text("IMAGE SIZE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(PrecisionTheme.textTertiary)
                Spacer()
                Button("Edit Presets…") { showPresetManager = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.blue)
            }

            // Mode Selector Bar
            HStack(spacing: 2) {
                modeButton(title: "Presets", mode: .preset)
                modeButton(title: "Bounds", mode: .fit)
                modeButton(title: "% Scale", mode: .percentage)
                modeButton(title: "Width", mode: .widthOnly)
                modeButton(title: "Height", mode: .heightOnly)
            }
            .padding(2)
            .background(PrecisionTheme.recessedBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(PrecisionTheme.borderSubtle, lineWidth: 1)
            )

            // Dynamic Mode Content
            switch configuration.mode {
            case .preset:
                presetRadioCards
            case .fit:
                customBoundsControls
            case .percentage:
                percentageControls
            case .widthOnly:
                widthOnlyControls
            case .heightOnly:
                heightOnlyControls
            }

            // Zero Distortion Guarantee Callout
            MathematicalGuaranteeCard()

            // Processing Parameters
            processingParametersSection

            // Active Sample Envelope Pill
            if let sample = sampleItem {
                sampleEnvelopeBanner(sample: sample)
            }

            // Bottom Action Bar
            if showsActionBar { bottomActionBar }
        }
        .padding(16)
        .background(PrecisionTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PrecisionTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
    }

    private func modeButton(title: String, mode: ResizeMode) -> some View {
        let isSelected = configuration.mode == mode
        return Button(action: {
            selectMode(mode)
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? PrecisionTheme.textPrimary : PrecisionTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(isSelected ? PrecisionTheme.cardBackground : Color.clear)
                .cornerRadius(6)
                .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func selectMode(_ mode: ResizeMode) {
        let oldMode = configuration.mode
        guard oldMode != mode else { return }
        ImageResizeEngine.adaptConfigurationOnModeChange(
            configuration: &configuration,
            from: oldMode,
            to: mode,
            preset: activePreset,
            availablePresets: presetStore.presets,
            sampleOriginal: sampleItem?.originalDimensions
        )
        configuration.mode = mode
    }

    // MARK: - Presets Radio Cards
    private var presetRadioCards: some View {
        VStack(spacing: 6) {
            ForEach(presetStore.presets) { preset in
                let isSelected = configuration.selectedPresetId == preset.id

                Button(action: {
                    configuration.selectedPresetId = preset.id
                }) {
                    HStack(spacing: 10) {
                        // Radio circle
                        ZStack {
                            Circle()
                                .stroke(isSelected ? PrecisionTheme.blue : PrecisionTheme.border, lineWidth: 1.5)
                                .frame(width: 14, height: 14)

                            if isSelected {
                                Circle()
                                    .fill(PrecisionTheme.blue)
                                    .frame(width: 7, height: 7)
                            }
                        }

                        // Preset titles
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 5) {
                                Text(preset.name)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                    .foregroundColor(isSelected ? PrecisionTheme.blue : PrecisionTheme.textPrimary)

                                if isSelected {
                                    Circle()
                                        .fill(PrecisionTheme.blue)
                                        .frame(width: 5, height: 5)
                                }
                            }

                            Text(presetSubtitle(for: preset))
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? PrecisionTheme.textSecondary : PrecisionTheme.textTertiary)
                        }

                        Spacer()

                        Text("\(preset.maxWidth) × \(preset.maxHeight) px")
                            .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular, design: .monospaced))
                            .foregroundColor(isSelected ? PrecisionTheme.blue : PrecisionTheme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(isSelected ? PrecisionTheme.blueLight : PrecisionTheme.cardBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? PrecisionTheme.blue.opacity(0.35) : PrecisionTheme.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func presetSubtitle(for preset: ResizePreset) -> String {
        switch preset.name.lowercased() {
        case "small": return "Thumbnails & preview assets"
        case "medium": return "Laptops & tablet web display"
        case "large": return "Monitors & primary web heroes"
        case "extra large": return "Retina & archival resolution"
        default: return "Fit within maximum boundary"
        }
    }

    // MARK: - Bounds Controls
    private var customBoundsControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            aspectRatioPillsSection

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Max Width")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(PrecisionTheme.textTertiary)
                    TextField("Width", value: $configuration.customWidth, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }

                Button(action: swapCustomDimensions) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(PrecisionTheme.blue)
                        .frame(width: 24, height: 24)
                        .background(PrecisionTheme.blueLight)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Swap Width & Height (Landscape ⇄ Portrait)")
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Max Height")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(PrecisionTheme.textTertiary)
                    TextField("Height", value: $configuration.customHeight, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
        }
    }

    // MARK: - Percentage Controls
    private var percentageControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scale Factor")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)
                Spacer()
                Text("\(Int(configuration.percentage))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(PrecisionTheme.blue)
            }

            Slider(value: $configuration.percentage, in: 10...300, step: 5)
                .tint(PrecisionTheme.blue)

            HStack(spacing: 4) {
                ForEach([25, 50, 75, 100, 150, 200], id: \.self) { val in
                    Button("\(val)%") {
                        configuration.percentage = Double(val)
                    }
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(Int(configuration.percentage) == val ? PrecisionTheme.blueLight : PrecisionTheme.recessedBackground)
                    .foregroundColor(Int(configuration.percentage) == val ? PrecisionTheme.blue : PrecisionTheme.textSecondary)
                    .cornerRadius(4)
                }
            }
        }
    }

    private var widthOnlyControls: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Target Width (px)")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(PrecisionTheme.textTertiary)
            TextField("Width", value: $configuration.customWidth, format: .number)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
        }
    }

    private var heightOnlyControls: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Target Height (px)")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(PrecisionTheme.textTertiary)
            TextField("Height", value: $configuration.customHeight, format: .number)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
        }
    }

    // MARK: - Processing Parameters Section
    private var processingParametersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROCESSING PARAMETERS")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(PrecisionTheme.textTertiary)
                .padding(.top, 4)

            VStack(spacing: 0) {
                parameterToggleRow(
                    title: "Allow upscaling of small images",
                    icon: "arrow.up.left.and.arrow.down.right",
                    isOn: $configuration.allowUpscaling
                )

                Divider().background(PrecisionTheme.borderSubtle)

                parameterToggleRow(
                    title: "Retain metadata & color profiles",
                    icon: "paintpalette",
                    isOn: $configuration.preserveMetadata
                )

                Divider().background(PrecisionTheme.borderSubtle)

                parameterToggleRow(
                    title: "Preserve creation & modified dates",
                    icon: "clock.arrow.circlepath",
                    isOn: $configuration.preserveFileTimestamps
                )
            }
        }
    }

    private func parameterToggleRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isOn.wrappedValue ? PrecisionTheme.blue : PrecisionTheme.textTertiary)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(PrecisionTheme.textPrimary)

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Sample Envelope Banner
    private func sampleEnvelopeBanner(sample: ImageItem) -> some View {
        let calculated = ImageResizeEngine.calculateDimensions(
            original: sample.originalDimensions,
            mode: configuration.mode,
            targetWidth: configuration.customWidth,
            targetHeight: configuration.customHeight,
            percentage: configuration.percentage,
            preset: activePreset,
            allowUpscaling: configuration.allowUpscaling
        )

        return HStack {
            Text("Active Sample Envelope")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(PrecisionTheme.textTertiary)

            Spacer()

            HStack(spacing: 6) {
                Text(sample.originalDimensions.description)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(PrecisionTheme.textSecondary)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(PrecisionTheme.blue)

                Text(calculated.description)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(PrecisionTheme.textPrimary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PrecisionTheme.cardHeaderBackground)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(PrecisionTheme.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isProcessing {
                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)
                Text(currentFilename.isEmpty ? (isPaused ? "Paused" : "Processing…") : "Processing: \(currentFilename)")
                    .font(.system(size: 10))
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack(spacing: 8) {
            Button(action: onStartResize) {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                    }

                    Text(queueCount > 0 ? "Compress \(queueCount) \(queueCount == 1 ? "File" : "Files")" : "Compress Files")
                        .font(.system(size: 12.5, weight: .semibold))

                    ShortcutBadge("⌘↵")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(queueCount > 0 && !isProcessing ? PrecisionTheme.blue : PrecisionTheme.blue.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: PrecisionTheme.blue.opacity(0.25), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .disabled(queueCount == 0 || isProcessing)
            .keyboardShortcut(.return, modifiers: .command)

            if isProcessing {
                Button(action: isPaused ? onResume : onPause) {
                    Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button(action: onStop) {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Format & Output Card
    private var formatAndOutputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hasVideo ? "VIDEO EXPORT · MP4" : "OUTPUT FORMAT & QUALITY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PrecisionTheme.textTertiary)

            HStack {
                Text(hasVideo ? "Output" : "Format")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(PrecisionTheme.textPrimary)

                Spacer()

                if !hasVideo { Picker("", selection: $configuration.outputFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140) }
            }

            if configuration.outputFormat.supportsQuality {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Compression Quality")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(PrecisionTheme.textTertiary)
                        Spacer()
                        Text("\(Int(configuration.quality * 100))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(PrecisionTheme.blue)
                    }

                    Slider(value: $configuration.quality, in: 0.1...1.0, step: 0.05)
                        .tint(PrecisionTheme.blue)
                }
            }
        }
        .padding(14)
        .background(PrecisionTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PrecisionTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
    }

    // MARK: - Aspect Ratio Helper
    private var aspectRatioPillsSection: some View {
        let presets = areRatiosInverted ? AspectRatioPreset.all.map { $0.inverted() } : AspectRatioPreset.all

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Fit within bounds · preserve ratio")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .help("These dimensions set a maximum bounding box. Images are fitted inside it without cropping or stretching.")

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        areRatiosInverted.toggle()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9))
                        Text(areRatiosInverted ? "Portrait" : "Landscape")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(PrecisionTheme.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(PrecisionTheme.blueLight)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(presets) { preset in
                        Button(action: {
                            applyAspectRatio(preset)
                        }) {
                            Text(preset.ratioLabel)
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(PrecisionTheme.recessedBackground)
                                .foregroundColor(PrecisionTheme.textPrimary)
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(PrecisionTheme.borderSubtle, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("\(preset.name) (\(preset.width) × \(preset.height) px)")
                    }
                }
            }
        }
    }

    private func applyAspectRatio(_ preset: AspectRatioPreset) {
        configuration.customWidth = preset.width
        configuration.customHeight = preset.height
    }

    private func swapCustomDimensions() {
        let oldWidth = configuration.customWidth
        configuration.customWidth = configuration.customHeight
        configuration.customHeight = oldWidth
    }
}
