import Foundation

/// Integer rasterizers for the shape tools. Pure geometry: these return the cells a
/// shape covers; bounds-clipping happens where the points are written to a grid.
extension PixelGrid {
    struct Point: Hashable, Sendable {
        var x: Int
        var y: Int
    }

    /// Cells on the Bresenham line between two cells, inclusive.
    static func linePoints(from start: Point, to end: Point) -> [Point] {
        var points: [Point] = []
        var x = start.x
        var y = start.y
        let dx = abs(end.x - start.x)
        let sx = start.x < end.x ? 1 : -1
        let dy = -abs(end.y - start.y)
        let sy = start.y < end.y ? 1 : -1
        var err = dx + dy
        while true {
            points.append(Point(x: x, y: y))
            let e2 = 2 * err
            if e2 >= dy {
                if x == end.x { break }
                err += dy
                x += sx
            }
            if e2 <= dx {
                if y == end.y { break }
                err += dx
                y += sy
            }
        }
        return points
    }

    /// Cells on the outline of the rectangle spanned by two corners, inclusive.
    static func rectanglePoints(from start: Point, to end: Point) -> [Point] {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        var points: [Point] = []
        for x in minX ... maxX {
            points.append(Point(x: x, y: minY))
            if maxY != minY { points.append(Point(x: x, y: maxY)) }
        }
        if maxY > minY + 1 {
            for y in (minY + 1) ... (maxY - 1) {
                points.append(Point(x: minX, y: y))
                if maxX != minX { points.append(Point(x: maxX, y: y)) }
            }
        }
        return points
    }

    /// Cells on the outline of the ellipse inscribed in the rectangle spanned by two
    /// corners (Zingl's rasterizer, exact for both even and odd spans).
    static func ellipsePoints(from start: Point, to end: Point) -> [Point] {
        var x0 = min(start.x, end.x)
        var x1 = max(start.x, end.x)
        var y0 = min(start.y, end.y)
        var y1 = max(start.y, end.y)

        // A zero-width or zero-height box degenerates to a straight line, which
        // Zingl's algorithm does not cover (its flat-ellipse tail assumes width 1+).
        if x0 == x1 || y0 == y1 {
            return linePoints(from: Point(x: x0, y: y0), to: Point(x: x1, y: y1))
        }

        let a = x1 - x0
        let b = y1 - y0
        let b1 = b & 1
        var dx = Double(4 * (1 - a) * b * b)
        var dy = Double(4 * (b1 + 1) * a * a)
        var err = dx + dy + Double(b1 * a * a)

        y0 += (b + 1) / 2
        y1 = y0 - b1
        let a8 = Double(8 * a * a)
        let b8 = Double(8 * b * b)

        var points = Set<Point>()
        repeat {
            points.insert(Point(x: x1, y: y0))
            points.insert(Point(x: x0, y: y0))
            points.insert(Point(x: x0, y: y1))
            points.insert(Point(x: x1, y: y1))
            let e2 = 2 * err
            if e2 <= dy {
                y0 += 1
                y1 -= 1
                dy += a8
                err += dy
            }
            if e2 >= dx || 2 * err > dy {
                x0 += 1
                x1 -= 1
                dx += b8
                err += dx
            }
        } while x0 <= x1

        // Finish the flat top/bottom of tall, narrow ellipses.
        while y0 - y1 < b {
            points.insert(Point(x: x0 - 1, y: y0))
            points.insert(Point(x: x1 + 1, y: y0))
            y0 += 1
            points.insert(Point(x: x0 - 1, y: y1))
            points.insert(Point(x: x1 + 1, y: y1))
            y1 -= 1
        }
        return Array(points)
    }
}
