import Foundation
import Combine
import Sparkle

/// Manages automatic software updates and user-initiated update checks via Sparkle.
@MainActor
public final class UpdateManager: NSObject, ObservableObject {
    public static let shared = UpdateManager()

    /// Indicates whether an update check can currently be triggered
    @Published public private(set) var canCheckForUpdates: Bool = false

    /// The underlying Sparkle standard updater controller
    public private(set) var updaterController: SPUStandardUpdaterController?

    private var cancellables = Set<AnyCancellable>()

    public override init() {
        super.init()
        setupSparkle()
    }

    private func setupSparkle() {
        // Avoid starting updater in unit test environments
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        guard !isRunningTests else { return }

        // Initialize SPUStandardUpdaterController with standard driver
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.updaterController = controller

        // Observe the KVO canCheckForUpdates property on SPUUpdater
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    /// Explicitly check for updates and present the Sparkle UI dialog
    public func checkForUpdates() {
        guard let updaterController = updaterController else { return }
        updaterController.checkForUpdates(nil)
    }

    /// Whether automatic update checks are enabled
    public var automaticallyChecksForUpdates: Bool {
        get { updaterController?.updater.automaticallyChecksForUpdates ?? true }
        set {
            objectWillChange.send()
            updaterController?.updater.automaticallyChecksForUpdates = newValue
        }
    }

    /// Whether updates are downloaded in the background automatically
    public var automaticallyDownloadsUpdates: Bool {
        get { updaterController?.updater.automaticallyDownloadsUpdates ?? false }
        set {
            objectWillChange.send()
            updaterController?.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    /// Date of the most recent update check
    public var lastUpdateCheckDate: Date? {
        updaterController?.updater.lastUpdateCheckDate
    }

    /// The update feed URL from Info.plist
    public var feedURL: URL? {
        updaterController?.updater.feedURL
    }
}

// MARK: - SPUUpdaterDelegate
extension UpdateManager: SPUUpdaterDelegate {
    public func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        // Appcast loaded successfully
    }
}
