import SwiftUI
import UIKit

extension Color {
    init(_ pixel: PixelColor) {
        self = Color(
            .sRGB,
            red: Double(pixel.r) / 255,
            green: Double(pixel.g) / 255,
            blue: Double(pixel.b) / 255,
            opacity: Double(pixel.a) / 255)
    }
}

extension PixelColor {
    /// Converts a SwiftUI color to an opaque pixel color (alpha forced to 255 for
    /// drawing; the eraser is the way to make pixels transparent).
    init(_ color: Color) {
        let resolved = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(
            r: PixelColor.channel(r),
            g: PixelColor.channel(g),
            b: PixelColor.channel(b),
            a: 255)
    }

    private static func channel(_ value: CGFloat) -> UInt8 {
        UInt8((max(0, min(1, value)) * 255).rounded())
    }
}

enum PixelPalette {
    /// A compact default palette spanning common pixel-art hues.
    static let colors: [PixelColor] = [
        PixelColor(r: 0, g: 0, b: 0),
        PixelColor(r: 255, g: 255, b: 255),
        PixelColor(r: 155, g: 155, b: 155),
        PixelColor(r: 229, g: 0, b: 0),
        PixelColor(r: 229, g: 137, b: 0),
        PixelColor(r: 229, g: 229, b: 0),
        PixelColor(r: 0, g: 190, b: 0),
        PixelColor(r: 0, g: 158, b: 170),
        PixelColor(r: 0, g: 83, b: 229),
        PixelColor(r: 130, g: 0, b: 229),
        PixelColor(r: 229, g: 0, b: 178),
        PixelColor(r: 160, g: 106, b: 66),
    ]
}
