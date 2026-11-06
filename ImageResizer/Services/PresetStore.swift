import Foundation

public final class PresetStore: ObservableObject {
    public static let shared = PresetStore()

    private let userDefaultsKey = "com.antigravity.imageresizer.presets"

    @Published public var presets: [ResizePreset] = []

    public init() {
        loadPresets()
    }

    public func preset(for id: UUID) -> ResizePreset? {
        presets.first(where: { $0.id == id })
    }

    public func addPreset(name: String, maxWidth: Int, maxHeight: Int) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Custom Preset" : trimmedName
        let newPreset = ResizePreset(
            name: finalName,
            maxWidth: max(1, maxWidth),
            maxHeight: max(1, maxHeight),
            isBuiltIn: false
        )
        presets.append(newPreset)
        savePresets()
    }

    public func updatePreset(_ preset: ResizePreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }

    public func deletePreset(id: UUID) {
        presets.removeAll(where: { $0.id == id && !$0.isBuiltIn })
        savePresets()
    }

    public func movePresets(fromOffsets source: IndexSet, toOffset destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        savePresets()
    }

    public func resetToDefaults() {
        presets = ResizePreset.defaultPresets
        savePresets()
    }

    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ResizePreset].self, from: data),
           !decoded.isEmpty {
            self.presets = decoded
        } else {
            self.presets = ResizePreset.defaultPresets
        }
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
