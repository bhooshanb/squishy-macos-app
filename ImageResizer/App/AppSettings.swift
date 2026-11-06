import Foundation
import SwiftUI
import AppKit

public enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    public var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let configKey = "com.antigravity.imageresizer.configuration"
    private let appearanceKey = "com.antigravity.imageresizer.appearance"

    @Published public var configuration: ResizeConfiguration {
        didSet {
            saveConfiguration()
        }
    }

    @Published public var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey)
            applyAppearance()
        }
    }

    public init() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(ResizeConfiguration.self, from: data) {
            self.configuration = decoded
        } else {
            self.configuration = ResizeConfiguration.default
        }

        if let savedAppearance = UserDefaults.standard.string(forKey: appearanceKey),
           let parsed = AppAppearance(rawValue: savedAppearance) {
            self.appearance = parsed
        } else {
            self.appearance = .system
        }

        applyAppearance()
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    public func applyAppearance() {
        DispatchQueue.main.async {
            switch self.appearance {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }

    public func resetToDefaults() {
        self.configuration = ResizeConfiguration.default
        self.appearance = .system
    }
}
