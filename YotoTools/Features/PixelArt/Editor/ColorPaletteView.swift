import SwiftUI

/// Swatch palette plus a custom color picker. Selecting either updates `activeColor`.
struct ColorPaletteView: View {
    @Binding var activeColor: PixelColor
    @Binding var customColor: Color

    private let columns = [GridItem(.adaptive(minimum: 40), spacing: 10)]

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(PixelPalette.colors.enumerated()), id: \.offset) { _, color in
                    Button {
                        activeColor = color
                    } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(color))
                            .frame(height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        activeColor == color ? Color.accentColor : Color.black.opacity(0.15),
                                        lineWidth: activeColor == color ? 3 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Palette color")
                }
            }

            ColorPicker(selection: $customColor, supportsOpacity: false) {
                Text("Custom color")
            }
            .onChange(of: customColor) { _, newValue in
                activeColor = PixelColor(newValue)
            }
        }
        .padding(.horizontal)
    }
}
