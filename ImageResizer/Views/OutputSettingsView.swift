import SwiftUI
import AppKit

public struct OutputSettingsView: View {
    @Binding public var configuration: ResizeConfiguration
    @ObservedObject private var appSettings = AppSettings.shared
    @ObservedObject private var updateManager = UpdateManager.shared

    public init(configuration: Binding<ResizeConfiguration>) {
        self._configuration = configuration
    }

    private var samplePreviewName: String {
        let base = "IMG_4821"
        var name = base
        if !configuration.filenameSuffix.isEmpty {
            name += configuration.filenameSuffix
        }
        if configuration.appendPresetNameToFilename {
            name += "_large"
        }
        let ext = configuration.outputFormat == .original ? "jpg" : configuration.outputFormat.fileExtension
        return "\(name).\(ext)"
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PrecisionTheme.textPrimary)

                    Text("Configure appearance, export destination, filename rules, and format compression.")
                        .font(.system(size: 12))
                        .foregroundColor(PrecisionTheme.textTertiary)
                }

                // Group 0: Appearance / Theme
                appearanceCard

                // Group 1: Destination Folder & Collisions
                destinationCard

                // Group 2: Filename Pattern
                filenamePatternCard

                // Group 3: Compression & Codec
                codecAndQualityCard

                // Group 4: Metadata & Timestamps
                metadataAndTimestampsCard

                // Group 5: Software Updates (Git Feed)
                updatesCard
            }
            .padding(20)
        }
        .background(PrecisionTheme.background)
    }

    // MARK: - Appearance Card
    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundColor(PrecisionTheme.blue)
                Text("Appearance")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            HStack(spacing: 12) {
                ForEach(AppAppearance.allCases) { mode in
                    let isSelected = appSettings.appearance == mode
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            appSettings.appearance = mode
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isSelected ? PrecisionTheme.blue : PrecisionTheme.textSecondary)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(mode.rawValue)
                                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                                    .foregroundColor(isSelected ? PrecisionTheme.blue : PrecisionTheme.textPrimary)

                                Text(appearanceSubtitle(for: mode))
                                    .font(.system(size: 10))
                                    .foregroundColor(PrecisionTheme.textTertiary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(PrecisionTheme.blue)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? PrecisionTheme.blueLight : PrecisionTheme.recessedBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? PrecisionTheme.blue.opacity(0.4) : PrecisionTheme.borderSubtle, lineWidth: 1)
                        )
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

    private func appearanceSubtitle(for mode: AppAppearance) -> String {
        switch mode {
        case .system: return "Match macOS"
        case .light: return "Light theme"
        case .dark: return "Dark theme"
        }
    }

    // MARK: - Destination Folder Card
    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(PrecisionTheme.blue)
                Text("Export Destination")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                destinationOptionRow(
                    mode: .subfolder,
                    title: "Subfolder beside original",
                    subtitle: "Exports placed in a dedicated folder (e.g. \"\(configuration.subfolderName)\")"
                )

                if configuration.destinationMode == .subfolder {
                    HStack(spacing: 8) {
                        Text("Subfolder name:")
                            .font(.system(size: 11))
                            .foregroundColor(PrecisionTheme.textSecondary)

                        TextField("Subfolder", text: $configuration.subfolderName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .frame(width: 140)
                    }
                    .padding(.leading, 26)
                }

                destinationOptionRow(
                    mode: .sameFolder,
                    title: "Same folder as source",
                    subtitle: "Exports placed directly alongside original image files"
                )

                destinationOptionRow(
                    mode: .customFolder,
                    title: "Custom directory",
                    subtitle: "Save all resized images to a specific central folder"
                )

                if configuration.destinationMode == .customFolder {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 12))
                                .foregroundColor(PrecisionTheme.textTertiary)

                            Text(configuration.customDestinationPath ?? "~/Pictures/Exports")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(PrecisionTheme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PrecisionTheme.recessedBackground)
                        .cornerRadius(6)

                        Button("Choose Folder…") {
                            chooseCustomFolder()
                        }
                        .buttonStyle(.bordered)
                        .font(.system(size: 11))
                    }
                    .padding(.leading, 26)
                }
            }

            Divider().background(PrecisionTheme.borderSubtle).padding(.top, 4)

            // Collision Protection
            VStack(alignment: .leading, spacing: 8) {
                Text("COLLISION PROTECTION")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(PrecisionTheme.textTertiary)

                Picker("Collision rule", selection: $configuration.collisionHandling) {
                    ForEach(CollisionHandling.allCases) { handling in
                        Text(handling.displayName).tag(handling)
                    }
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: 12))
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

    private func destinationOptionRow(mode: OutputDestinationMode, title: String, subtitle: String) -> some View {
        Button(action: {
            configuration.destinationMode = mode
        }) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(configuration.destinationMode == mode ? PrecisionTheme.blue : PrecisionTheme.border, lineWidth: 1.5)
                        .frame(width: 14, height: 14)

                    if configuration.destinationMode == mode {
                        Circle()
                            .fill(PrecisionTheme.blue)
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(configuration.destinationMode == mode ? PrecisionTheme.blue : PrecisionTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(PrecisionTheme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filename Pattern Card
    private var filenamePatternCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundColor(PrecisionTheme.blue)
                Text("Filename Pattern")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Tokens")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(PrecisionTheme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Filename Suffix")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)

                HStack(spacing: 8) {
                    TextField("Suffix", text: $configuration.filenameSuffix)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 160)

                    Toggle("Append Preset Name", isOn: $configuration.appendPresetNameToFilename)
                        .font(.system(size: 12))
                }
            }

            // Live Preview Transformation Pill
            HStack(spacing: 8) {
                Text("Live Preview:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)

                Text("IMG_4821.jpg")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(PrecisionTheme.textTertiary)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(PrecisionTheme.blue)

                Text(samplePreviewName)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(PrecisionTheme.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(PrecisionTheme.blueLight)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(PrecisionTheme.recessedBackground)
            .cornerRadius(6)
        }
        .padding(16)
        .background(PrecisionTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PrecisionTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Codec & Quality Card
    private var codecAndQualityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(PrecisionTheme.blue)
                Text("Compression & Codec")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("CoreGraphics")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(PrecisionTheme.textTertiary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target Format")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(PrecisionTheme.textPrimary)
                    Text("Preserve original file container or transcode")
                        .font(.system(size: 11))
                        .foregroundColor(PrecisionTheme.textTertiary)
                }

                Spacer()

                Picker("", selection: $configuration.outputFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            if configuration.outputFormat.supportsQuality {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Quality")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(PrecisionTheme.textSecondary)
                        Spacer()
                        Text("\(Int(configuration.quality * 100))%")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(PrecisionTheme.blue)
                    }

                    Slider(value: $configuration.quality, in: 0.1...1.0, step: 0.05)
                        .tint(PrecisionTheme.blue)
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

    // MARK: - Metadata & Timestamps Card
    private var metadataAndTimestampsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(PrecisionTheme.blue)
                Text("Metadata & Preservation")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            Toggle("Preserve EXIF, GPS & Color Profiles", isOn: $configuration.preserveMetadata)
                .font(.system(size: 12))

            Toggle("Preserve Creation & Modified File Timestamps", isOn: $configuration.preserveFileTimestamps)
                .font(.system(size: 12))
        }
        .padding(16)
        .background(PrecisionTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PrecisionTheme.border, lineWidth: 1)
        )
    }

    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Destination Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            configuration.customDestinationPath = url.path
        }
    }

    // MARK: - Software Updates Card
    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundColor(PrecisionTheme.blue)
                Text("Software Updates (Git Feed)")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()

                StatusPill(title: "Git appcast.xml", isPositive: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Installed Version: v\(appVersionString) (Build \(appBuildString))")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(PrecisionTheme.textPrimary)

                        HStack(spacing: 4) {
                            Text("Feed:")
                                .font(.system(size: 10.5))
                                .foregroundColor(PrecisionTheme.textTertiary)

                            Text(updateManager.activeFeedURLString)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundColor(PrecisionTheme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    Spacer()

                    Button(action: {
                        updateManager.checkForUpdates()
                    }) {
                        HStack(spacing: 5) {
                            if updateManager.isCheckingForUpdates {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text("Check for Updates")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PrecisionTheme.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(updateManager.isCheckingForUpdates)
                }

                Divider().background(PrecisionTheme.borderSubtle)

                Toggle("Automatically check for updates via GitHub appcast.xml", isOn: Binding(
                    get: { updateManager.automaticallyChecksForUpdates },
                    set: { updateManager.automaticallyChecksForUpdates = $0 }
                ))
                .font(.system(size: 12))
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

    private var appVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appBuildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
