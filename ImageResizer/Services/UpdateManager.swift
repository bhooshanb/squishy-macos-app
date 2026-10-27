import Foundation
import Combine
import Sparkle

/// Manages automatic software updates and user-initiated update checks via Sparkle.
@MainActor
public final class UpdateManager: NSObject, ObservableObject {
    public static let shared = UpdateManager()

    /// Default git repository raw appcast.xml URL
    public static let defaultGitFeedURL = "https://raw.githubusercontent.com/bhooshanb/squishy-macos-app/master/appcast.xml"

    /// Indicates whether an update check can currently be triggered
    @Published public private(set) var canCheckForUpdates: Bool = false

    /// Indicates whether an update check is currently in progress
    @Published public private(set) var isCheckingForUpdates: Bool = false

    /// The active feed URL string
    @Published public private(set) var activeFeedURLString: String = UpdateManager.defaultGitFeedURL

    /// The underlying Sparkle standard updater controller
    public private(set) var updaterController: SPUStandardUpdaterController?

    private var cancellables = Set<AnyCancellable>()

    public override init() {
        super.init()
        setupSparkle()
    }

    private func setupSparkle() {
        // Resolve feed URL from Info.plist or default git raw url
        if let bundleFeed = Bundle.main.infoDictionary?["SUFeedURL"] as? String, !bundleFeed.isEmpty {
            self.activeFeedURLString = bundleFeed
        } else {
            self.activeFeedURLString = Self.defaultGitFeedURL
        }

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

    /// Explicitly check for updates using the git-hosted appcast.xml and present the Sparkle UI dialog
    public func checkForUpdates() {
        guard let updaterController = updaterController else { return }
        isCheckingForUpdates = true
        updaterController.checkForUpdates(nil)
        
        // Reset checking indicator after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isCheckingForUpdates = false
        }
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
        updaterController?.updater.feedURL ?? URL(string: activeFeedURLString)
    }
}

// MARK: - SPUUpdaterDelegate
extension UpdateManager: SPUUpdaterDelegate {
    /// Return the git-hosted appcast.xml feed URL to Sparkle
    public func feedURLString(for updater: SPUUpdater) -> String? {
        return activeFeedURLString
    }

    public func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        Task { @MainActor in
            self.isCheckingForUpdates = false
        }
    }

    public func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        Task { @MainActor in
            self.isCheckingForUpdates = false
        }
    }
}
