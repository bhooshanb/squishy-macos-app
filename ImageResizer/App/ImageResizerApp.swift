import SwiftUI

import SwiftUI

@main
struct ImageResizerApp: App {
    @StateObject private var updateManager = UpdateManager.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 540)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updateManager.checkForUpdates()
                }
                .disabled(!updateManager.canCheckForUpdates)
            }

            CommandGroup(replacing: .newItem) {
                Button("Open Images…") {
                    let urls = ImageFileService.shared.selectFilesWithOpenPanel(allowsMultiple: true)
                    NotificationCenter.default.post(name: .openImagesNotification, object: urls)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("Image Resizer Help") {
                    if let url = URL(string: "https://github.com/microsoft/PowerToys/tree/main/src/modules/imageresizer") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Divider()
                Button("Check for Updates…") {
                    updateManager.checkForUpdates()
                }
                .disabled(!updateManager.canCheckForUpdates)
            }
        }

        Settings {
            UpdateSettingsView()
        }
    }
}

extension Notification.Name {
    static let openImagesNotification = Notification.Name("com.antigravity.imageresizer.openImages")
}
