import SwiftUI

public struct PresetManagerSheet: View {
    @ObservedObject var presetStore = PresetStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""
    @State private var newWidth: String = "1280"
    @State private var newHeight: String = "720"
    @State private var isAddingPreset: Bool = false
    @State private var errorMessage: String? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Manage Presets")
                    .font(.title2.weight(.bold))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Text("Presets define maximum bounding dimensions. Images are scaled proportionally without distortion.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Preset List
            List {
                ForEach(presetStore.presets) { preset in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(preset.name)
                                    .font(.headline)
                                if preset.isBuiltIn {
                                    Text("Built-in")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                            Text("Max \(preset.maxWidth) × \(preset.maxHeight) px")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !preset.isBuiltIn {
                            Button(role: .destructive) {
                                presetStore.deletePreset(id: preset.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete custom preset")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove { indices, newOffset in
                    presetStore.movePresets(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(height: 220)

            // Add New Preset Form
            if isAddingPreset {
                VStack(alignment: .leading, spacing: 10) {
                    Text("New Preset")
                        .font(.headline)

                    HStack(spacing: 12) {
                        TextField("Preset Name", text: $newName)
                            .textFieldStyle(.roundedBorder)

                        TextField("Max Width", text: $newWidth)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)

                        Text("×")
                            .foregroundColor(.secondary)

                        TextField("Max Height", text: $newHeight)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)

                        Button("Add") {
                            addPreset()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Cancel") {
                            isAddingPreset = false
                            errorMessage = nil
                        }
                        .buttonStyle(.plain)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }

            // Bottom action row
            HStack {
                Button(action: {
                    isAddingPreset.toggle()
                }) {
                    Label("Add Preset", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Reset to Defaults") {
                    presetStore.resetToDefaults()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 540, height: 460)
    }

    private func addPreset() {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a preset name."
            return
        }
        guard let w = Int(newWidth), w > 0,
              let h = Int(newHeight), h > 0 else {
            errorMessage = "Please enter valid positive dimensions."
            return
        }

        presetStore.addPreset(name: newName, maxWidth: w, maxHeight: h)
        newName = ""
        newWidth = "1280"
        newHeight = "720"
        isAddingPreset = false
        errorMessage = nil
    }
}
