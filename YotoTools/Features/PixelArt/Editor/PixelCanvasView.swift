import SwiftUI

/// Renders a `PixelGrid` scaled up to fill available space and routes touches back
/// as cell coordinates. Logic-free: drawing decisions live in the view model.
struct PixelCanvasView: View {
    let grid: PixelGrid
    let showsGrid: Bool
    /// Called with the cell coordinate and whether this is the first touch of a stroke.
    let onDraw: (Int, Int, Bool) -> Void

    @State private var isStroking = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(PixelGrid.side)

            Canvas { context, _ in
                drawCheckerboard(in: &context, cell: cell)
                drawPixels(in: &context, cell: cell)
                if showsGrid { drawGridLines(in: &context, cell: cell, side: side) }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = Int((value.location.x / cell).rounded(.down))
                        let y = Int((value.location.y / cell).rounded(.down))
                        onDraw(x, y, !isStroking)
                        isStroking = true
                    }
                    .onEnded { _ in isStroking = false }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drawCheckerboard(in context: inout GraphicsContext, cell: CGFloat) {
        let light = Color(white: 0.96)
        let dark = Color(white: 0.86)
        for y in 0..<PixelGrid.side {
            for x in 0..<PixelGrid.side {
                let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                context.fill(Path(rect), with: .color((x + y).isMultiple(of: 2) ? light : dark))
            }
        }
    }

    private func drawPixels(in context: inout GraphicsContext, cell: CGFloat) {
        for y in 0..<PixelGrid.side {
            for x in 0..<PixelGrid.side {
                let color = grid.color(x: x, y: y)
                guard !color.isClear else { continue }
                let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                context.fill(Path(rect), with: .color(Color(color)))
            }
        }
    }

    private func drawGridLines(in context: inout GraphicsContext, cell: CGFloat, side: CGFloat) {
        var path = Path()
        for i in 0...PixelGrid.side {
            let offset = CGFloat(i) * cell
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset, y: side))
            path.move(to: CGPoint(x: 0, y: offset))
            path.addLine(to: CGPoint(x: side, y: offset))
        }
        context.stroke(path, with: .color(Color.black.opacity(0.12)), lineWidth: 0.5)
    }
}
