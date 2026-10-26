import SwiftUI

public struct DropOverlayView: View {
    public var body: some View {
        ZStack {
            Color.accentColor.opacity(0.12)
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                .padding(16)

            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.accentColor)
                Text("Drop Images to Add")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                Text("Supported formats: JPEG, PNG, HEIC, WebP, TIFF, BMP, GIF")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .allowsHitTesting(false)
    }
}
