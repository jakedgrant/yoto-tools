import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A fixed 16×16 grid of pixels — the native resolution of a Yoto track icon.
struct PixelGrid: Equatable, Sendable {
    static let side = 16
    static let pixelCount = side * side
    static let byteCount = pixelCount * 4

    private(set) var pixels: [PixelColor]

    init() {
        pixels = Array(repeating: .clear, count: Self.pixelCount)
    }

    init(pixels: [PixelColor]) {
        precondition(pixels.count == Self.pixelCount, "PixelGrid requires \(Self.pixelCount) pixels")
        self.pixels = pixels
    }

    // MARK: Indexing

    func isInBounds(x: Int, y: Int) -> Bool {
        x >= 0 && x < Self.side && y >= 0 && y < Self.side
    }

    private func index(x: Int, y: Int) -> Int { y * Self.side + x }

    func color(x: Int, y: Int) -> PixelColor {
        pixels[index(x: x, y: y)]
    }

    mutating func setColor(_ color: PixelColor, x: Int, y: Int) {
        pixels[index(x: x, y: y)] = color
    }

    var isEmpty: Bool {
        pixels.allSatisfy { $0.isClear }
    }

    // MARK: Tools

    /// Flood fills the contiguous region of same-colored pixels starting at (x, y).
    mutating func floodFill(x: Int, y: Int, with newColor: PixelColor) {
        guard isInBounds(x: x, y: y) else { return }
        let target = color(x: x, y: y)
        guard target != newColor else { return }

        var stack = [(x, y)]
        while let (px, py) = stack.popLast() {
            guard isInBounds(x: px, y: py), color(x: px, y: py) == target else { continue }
            setColor(newColor, x: px, y: py)
            stack.append((px + 1, py))
            stack.append((px - 1, py))
            stack.append((px, py + 1))
            stack.append((px, py - 1))
        }
    }

    // MARK: Serialization (1024 raw RGBA bytes)

    func encoded() -> Data {
        var data = Data(capacity: Self.byteCount)
        for pixel in pixels {
            data.append(pixel.r)
            data.append(pixel.g)
            data.append(pixel.b)
            data.append(pixel.a)
        }
        return data
    }

    init?(data: Data) {
        guard data.count == Self.byteCount else { return nil }
        var result = [PixelColor]()
        result.reserveCapacity(Self.pixelCount)
        var offset = data.startIndex
        for _ in 0..<Self.pixelCount {
            result.append(PixelColor(
                r: data[offset],
                g: data[offset + 1],
                b: data[offset + 2],
                a: data[offset + 3]))
            offset += 4
        }
        self.init(pixels: result)
    }

    // MARK: PNG export (exactly 16×16, non-interpolated)

    func pngData() -> Data? {
        var raw = [UInt8](repeating: 0, count: Self.byteCount)
        for y in 0..<Self.side {
            for x in 0..<Self.side {
                let pixel = color(x: x, y: y)
                let offset = (y * Self.side + x) * 4
                raw[offset] = pixel.r
                raw[offset + 1] = pixel.g
                raw[offset + 2] = pixel.b
                raw[offset + 3] = pixel.a
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(raw) as CFData),
              let image = CGImage(
                width: Self.side,
                height: Self.side,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: Self.side * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent)
        else { return nil }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }

    // MARK: Photo import (downscale to 16×16)

    /// Produces a grid by drawing `cgImage` into a 16×16 RGBA context.
    init(downscaling cgImage: CGImage) {
        var grid = PixelGrid()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var raw = [UInt8](repeating: 0, count: Self.byteCount)
        raw.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: Self.side,
                height: Self.side,
                bitsPerComponent: 8,
                bytesPerRow: Self.side * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            context.interpolationQuality = .none
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        }
        for y in 0..<Self.side {
            for x in 0..<Self.side {
                let offset = (y * Self.side + x) * 4
                grid.setColor(
                    PixelColor(r: raw[offset], g: raw[offset + 1], b: raw[offset + 2], a: raw[offset + 3]),
                    x: x,
                    y: y)
            }
        }
        self = grid
    }
}
