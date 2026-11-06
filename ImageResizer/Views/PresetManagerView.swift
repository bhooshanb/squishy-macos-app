import SwiftUI

public struct PresetManagerView: View {
    @ObservedObject var presetStore = PresetStore.shared
    public var onClose: (() -> Void)? = nil

    @State private var filterQuery: String = ""
    @State private var isAddingPreset: Bool = false
    @State private var newName: String = ""
    @State private var newWidth: String = "1280"
    @State private var newHeight: String = "720"
    @State private var errorMessage: String? = nil

    public init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    private var filteredPresets: [ResizePreset] {
        if filterQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return presetStore.presets
        }
        return presetStore.presets.filter {
            $0.name.localizedCaseInsensitiveContains(filterQuery) ||
            "\($0.maxWidth)".contains(filterQuery) ||
            "\($0.maxHeight)".contains(filterQuery)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header & Search Strip
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Preset Manager")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(PrecisionTheme.textPrimary)

                        Text("Configure target dimensions, aspect constraints, and scaling policies.")
                            .font(.system(size: 12))
                            .foregroundColor(PrecisionTheme.textTertiary)
                    }

                    Spacer()

                    // Search input
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(PrecisionTheme.textTertiary)

                        TextField("Filter presets…", text: $filterQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .frame(width: 130)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(PrecisionTheme.cardBackground)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(PrecisionTheme.border, lineWidth: 1)
                    )

                    // Add Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isAddingPreset.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isAddingPreset ? "xmark" : "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text(isAddingPreset ? "Cancel" : "New Preset")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isAddingPreset ? PrecisionTheme.recessedBackground : PrecisionTheme.textPrimary)
                        .foregroundColor(isAddingPreset ? PrecisionTheme.textPrimary : PrecisionTheme.cardBackground)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    if let onClose = onClose {
                        Button("Done", action: onClose)
                            .font(.system(size: 12, weight: .medium))
                            .buttonStyle(.bordered)
                    }
                }

                // Add Preset Card if toggled
                if isAddingPreset {
                    addPresetCard
                }

                // Presets Table Card
                presetsTableCard
            }
            .padding(20)
        }
        .background(PrecisionTheme.background)
    }

    private var addPresetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create Custom Preset")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(PrecisionTheme.textPrimary)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preset Name")
                        .font(.system(size: 10.5))
                        .foregroundColor(PrecisionTheme.textTertiary)
                    TextField("e.g. Blog Banner", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Max Width (px)")
                        .font(.system(size: 10.5))
                        .foregroundColor(PrecisionTheme.textTertiary)
                    TextField("Width", text: $newWidth)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 90)
                }

                Text("×")
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .padding(.top, 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Max Height (px)")
                        .font(.system(size: 10.5))
                        .foregroundColor(PrecisionTheme.textTertiary)
                    TextField("Height", text: $newHeight)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 90)
                }

                Button("Save Preset") {
                    savePreset()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 14)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(PrecisionTheme.danger)
            }
        }
        .padding(14)
        .background(PrecisionTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(PrecisionTheme.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private var presetsTableCard: some View {
        VStack(spacing: 0) {
            // Table Header
            HStack {
                Text("Name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .frame(width: 220, alignment: .leading)

                Text("Max Dimensions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .frame(width: 160, alignment: .leading)

                Text("Category")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)

                Spacer()

                Text("Action")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrecisionTheme.textTertiary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(PrecisionTheme.cardHeaderBackground)

            Divider().background(PrecisionTheme.border)

            // Table Rows
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredPresets.enumerated()), id: \.element.id) { index, preset in
                    HStack {
                        // Name & Description
                        HStack(spacing: 8) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 13))
                                .foregroundColor(PrecisionTheme.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(PrecisionTheme.textPrimary)

                                Text(preset.isBuiltIn ? "System Standard Preset" : "User Defined Custom Preset")
                                    .font(.system(size: 10))
                                    .foregroundColor(PrecisionTheme.textTertiary)
                            }
                        }
                        .frame(width: 220, alignment: .leading)

                        // Max Dimensions
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(preset.maxWidth) × \(preset.maxHeight) px")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(PrecisionTheme.textPrimary)
                            Text("Fit within bounds")
                                .font(.system(size: 10))
                                .foregroundColor(PrecisionTheme.textTertiary)
                        }
                        .frame(width: 160, alignment: .leading)

                        // Category Badge
                        if preset.isBuiltIn {
                            Text("Built-in")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(PrecisionTheme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PrecisionTheme.recessedBackground)
                                .cornerRadius(4)
                        } else {
                            Text("Custom")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(PrecisionTheme.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PrecisionTheme.blueLight)
                                .cornerRadius(4)
                        }

                        Spacer()

                        // Action
                        if !preset.isBuiltIn {
                            Button(role: .destructive, action: {
                                presetStore.deletePreset(id: preset.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(PrecisionTheme.danger)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 50, alignment: .trailing)
                            .help("Delete preset")
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(PrecisionTheme.textTertiary.opacity(0.4))
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if index < filteredPresets.count - 1 {
                        Divider().background(PrecisionTheme.borderSubtle).padding(.horizontal, 12)
                    }
                }
            }
        }
        .background(PrecisionTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(PrecisionTheme.border, lineWidth: 1)
        )
    }

    private func savePreset() {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a preset name."
            return
        }
        guard let width = Int(newWidth), width > 0,
              let height = Int(newHeight), height > 0 else {
            errorMessage = "Width and Height must be positive integers."
            return
        }

        presetStore.addPreset(name: newName, maxWidth: width, maxHeight: height)
        newName = ""
        isAddingPreset = false
        errorMessage = nil
    }
}
