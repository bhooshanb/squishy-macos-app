import SwiftUI
import AppKit

@main
struct ImageResizerApp: App {
    @StateObject private var updateManager = UpdateManager.shared

    var body: some Scene {
        WindowGroup("Squishy") {
            MainView()
                .frame(minWidth: 800, minHeight: 540)
                .navigationTitle("Squishy")
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Squishy") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "Squishy",
                            .version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                            .applicationVersion: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Copyright © 2026 Silverstone Labs. All rights reserved.",
                            .credits: NSAttributedString(
                                string: "Created by Silverstone Labs\nWebsite: apps.silverstonelabs.in\nSupport: info@silverstonelabs.in",
                                attributes: [
                                    .foregroundColor: NSColor.secondaryLabelColor,
                                    .font: NSFont.systemFont(ofSize: 11)
                                ]
                            )
                        ]
                    )
                }
                Divider()
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
                Button("Squishy Help") {
                    if let url = URL(string: "https://apps.silverstonelabs.in") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Visit Silverstone Labs") {
                    if let url = URL(string: "https://apps.silverstonelabs.in") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Contact Support (info@silverstonelabs.in)") {
                    if let url = URL(string: "mailto:info@silverstonelabs.in?subject=Squishy%20Support") {
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
