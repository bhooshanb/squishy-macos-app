import SwiftUI

/// Settings view providing update preferences, branding, and support information.
public struct UpdateSettingsView: View {
    @ObservedObject private var updateManager = UpdateManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    if let appIcon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 52, height: 52)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Squishy")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Version \(appVersionString) (\(appBuildString))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let lastCheck = updateManager.lastUpdateCheckDate {
                            Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Last checked: Never")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        updateManager.checkForUpdates()
                    } label: {
                        Label("Check Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!updateManager.canCheckForUpdates)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Application")
            }

            Section {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updateManager.automaticallyChecksForUpdates },
                    set: { updateManager.automaticallyChecksForUpdates = $0 }
                ))

                Toggle("Automatically download new updates", isOn: Binding(
                    get: { updateManager.automaticallyDownloadsUpdates },
                    set: { updateManager.automaticallyDownloadsUpdates = $0 }
                ))
                .disabled(!updateManager.automaticallyChecksForUpdates)
            } header: {
                Text("Automatic Updates")
            } footer: {
                Text("Updates are verified cryptographically via Sparkle before installation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                LabeledContent("Created by") {
                    Text("Silverstone Labs")
                        .fontWeight(.medium)
                }

                LabeledContent("Website") {
                    Link("apps.silverstonelabs.in", destination: URL(string: "https://apps.silverstonelabs.in")!)
                }

                LabeledContent("Support") {
                    Link("info@silverstonelabs.in", destination: URL(string: "mailto:info@silverstonelabs.in?subject=Squishy%20Support")!)
                }

                LabeledContent("Copyright") {
                    Text("© 2026 Silverstone Labs")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About Silverstone Labs")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 380)
    }

    private var appVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appBuildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
