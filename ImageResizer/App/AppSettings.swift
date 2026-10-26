import Foundation

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let configKey = "com.antigravity.imageresizer.configuration"

    @Published public var configuration: ResizeConfiguration {
        didSet {
            saveConfiguration()
        }
    }

    public init() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(ResizeConfiguration.self, from: data) {
            self.configuration = decoded
        } else {
            self.configuration = ResizeConfiguration.default
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    public func resetToDefaults() {
        self.configuration = ResizeConfiguration.default
    }
}
