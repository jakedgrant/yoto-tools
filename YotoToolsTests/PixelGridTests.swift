import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import YotoTools

struct PixelGridTests {
    @Test func encodingRoundTrips() {
        var grid = PixelGrid()
        grid.setColor(.black, x: 0, y: 0)
        grid.setColor(PixelColor(r: 10, g: 20, b: 30), x: 5, y: 7)
        grid.setColor(.white, x: 15, y: 15)

        let data = grid.encoded()
        #expect(data.count == PixelGrid.byteCount)
        let restored = try! #require(PixelGrid(data: data))
        #expect(restored == grid)
    }

    @Test func decodeRejectsWrongSize() {
        #expect(PixelGrid(data: Data([1, 2, 3])) == nil)
    }

    @Test func pngExportIsExactly16x16() throws {
        var grid = PixelGrid()
        grid.setColor(PixelColor(r: 255, g: 0, b: 0), x: 3, y: 4)
        let data = try #require(grid.pngData())

        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 16)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 16)
    }

    @Test func pngRoundTripPreservesOpaquePixels() throws {
        var grid = PixelGrid()
        let red = PixelColor(r: 255, g: 0, b: 0)
        grid.setColor(red, x: 3, y: 4)
        let data = try #require(grid.pngData())

        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let cgImage = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let reimported = PixelGrid(downscaling: cgImage)

        #expect(reimported.color(x: 3, y: 4) == red)
        #expect(reimported.color(x: 0, y: 0).isClear)
    }

    @Test func floodFillStaysWithinContiguousRegion() {
        var grid = PixelGrid()
        // Build a vertical wall at x == 8 so fill on the left can't cross it.
        for y in 0..<PixelGrid.side {
            grid.setColor(.black, x: 8, y: y)
        }
        grid.floodFill(x: 0, y: 0, with: .white)

        #expect(grid.color(x: 0, y: 0) == .white)
        #expect(grid.color(x: 7, y: 5) == .white)
        #expect(grid.color(x: 8, y: 5) == .black) // wall untouched
        #expect(grid.color(x: 9, y: 5).isClear) // other side untouched
    }

    @Test func floodFillNoOpsWhenColorMatches() {
        var grid = PixelGrid()
        grid.floodFill(x: 0, y: 0, with: .clear)
        #expect(grid.isEmpty)
    }
}
