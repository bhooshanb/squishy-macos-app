import SwiftUI

public struct AspectRatioLockIndicator: View {
    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("Aspect Ratio Locked")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(6)
        .help("Images will always be scaled proportionally without stretching or distorting.")
    }
}
