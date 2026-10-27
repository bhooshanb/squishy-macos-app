import SwiftUI

public struct PresetManagerSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        PresetManagerView(onClose: {
            dismiss()
        })
        .frame(minWidth: 620, minHeight: 460)
    }
}
