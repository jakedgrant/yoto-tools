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

struct PixelShapeTests {
    @Test func linePointsWalkTheDiagonal() {
        let points = PixelGrid.linePoints(
            from: PixelGrid.Point(x: 0, y: 0),
            to: PixelGrid.Point(x: 3, y: 3))
        #expect(points == (0 ... 3).map { PixelGrid.Point(x: $0, y: $0) })
    }

    @Test func linePointsHandleReversedEndpoints() {
        let points = PixelGrid.linePoints(
            from: PixelGrid.Point(x: 4, y: 2),
            to: PixelGrid.Point(x: 1, y: 2))
        #expect(Set(points) == Set((1 ... 4).map { PixelGrid.Point(x: $0, y: 2) }))
    }

    @Test func rectanglePointsFormAnOutlineOnly() {
        let points = Set(PixelGrid.rectanglePoints(
            from: PixelGrid.Point(x: 1, y: 1),
            to: PixelGrid.Point(x: 4, y: 3)))
        #expect(points.contains(PixelGrid.Point(x: 1, y: 1)))
        #expect(points.contains(PixelGrid.Point(x: 4, y: 3)))
        #expect(points.contains(PixelGrid.Point(x: 2, y: 1)))
        #expect(points.contains(PixelGrid.Point(x: 1, y: 2)))
        #expect(!points.contains(PixelGrid.Point(x: 2, y: 2))) // interior untouched
        #expect(points.count == 10) // 2*4 + 2*3 - 4 corners
    }

    @Test func ellipsePointsAreSymmetricTouchExtremesAndStayInBox() {
        let points = Set(PixelGrid.ellipsePoints(
            from: PixelGrid.Point(x: 2, y: 2),
            to: PixelGrid.Point(x: 8, y: 6)))
        // Touches the middle of every bounding-box edge.
        #expect(points.contains(PixelGrid.Point(x: 5, y: 2)))
        #expect(points.contains(PixelGrid.Point(x: 5, y: 6)))
        #expect(points.contains(PixelGrid.Point(x: 2, y: 4)))
        #expect(points.contains(PixelGrid.Point(x: 8, y: 4)))
        for point in points {
            // Four-way symmetric about the box center (5, 4).
            #expect(points.contains(PixelGrid.Point(x: 10 - point.x, y: point.y)))
            #expect(points.contains(PixelGrid.Point(x: point.x, y: 8 - point.y)))
            // Never escapes the bounding box.
            #expect(point.x >= 2 && point.x <= 8 && point.y >= 2 && point.y <= 6)
        }
    }

    @Test func ellipsePointsDegenerateToALine() {
        let points = Set(PixelGrid.ellipsePoints(
            from: PixelGrid.Point(x: 3, y: 1),
            to: PixelGrid.Point(x: 3, y: 5)))
        #expect(points == Set((1 ... 5).map { PixelGrid.Point(x: 3, y: $0) }))
    }
}
