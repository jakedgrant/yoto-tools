import Foundation

/// An 8-bit-per-channel RGBA color. UIKit/SwiftUI-free so the model layer stays portable.
struct PixelColor: Equatable, Hashable, Sendable, Codable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8

    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    static let clear = PixelColor(r: 0, g: 0, b: 0, a: 0)
    static let black = PixelColor(r: 0, g: 0, b: 0)
    static let white = PixelColor(r: 255, g: 255, b: 255)

    var isClear: Bool { a == 0 }
}
