import SwiftUI

@main
struct ImageResizerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 540)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Images…") {
                    let urls = ImageFileService.shared.selectFilesWithOpenPanel(allowsMultiple: true)
                    // Post notification or trigger open if needed
                    NotificationCenter.default.post(name: .openImagesNotification, object: urls)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let openImagesNotification = Notification.Name("com.antigravity.imageresizer.openImages")
}
