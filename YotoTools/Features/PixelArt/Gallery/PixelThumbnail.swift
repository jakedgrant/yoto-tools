import SwiftUI
import UIKit

/// Crisp, non-interpolated thumbnail of a 16×16 grid, scaled to fit.
struct PixelThumbnail: View {
    let grid: PixelGrid

    var body: some View {
        ZStack {
            Color(white: 0.95)
            if let data = grid.pngData(), let image = UIImage(data: data) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}
