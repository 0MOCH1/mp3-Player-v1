import SwiftUI
import UIKit

struct ArtworkImageView: View {
    let artworkUri: String?
    var cornerRadius: CGFloat = 0
    var contentMode: ContentMode = .fill
    var placeholderSystemImage: String = "music.note"
    /// When true, crops non-square images to square based on short side (default: true)
    var cropToSquare: Bool = true
    
    @State private var image: Image?
    @Environment(\.displayScale) private var displayScale
    
    private var onePixel: CGFloat {
        1 / displayScale
    }


    var body: some View {
        ZStack {
            Rectangle()
                .fill(.secondary.opacity(0.15))
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: cropToSquare ? .fill : contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: placeholderSystemImage)
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1.0, contentMode: .fit) // Ensure container is square
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: onePixel)
                    .allowsHitTesting(false)
            }
        .task(id: artworkUri) {
            image = await loadImage()
        }
    }

    private func loadImage() async -> Image? {
        guard let artworkUri, let url = URL(string: artworkUri) else { return nil }
        let data = await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value
        guard let data, let uiImage = UIImage(data: data) else { return nil }
        
        // Crop to square if needed
        if cropToSquare {
            let croppedImage = cropImageToSquare(uiImage)
            return Image(uiImage: croppedImage)
        }
        
        return Image(uiImage: uiImage)
    }
    
    /// Crops a UIImage to square based on the shorter dimension
    private func cropImageToSquare(_ image: UIImage) -> UIImage {
        let size = image.size
        let scale = image.scale
        
        // Already square, return as-is
        if size.width == size.height {
            return image
        }
        
        // Use the shorter dimension as the square size
        let squareSize = min(size.width, size.height)
        let x = (size.width - squareSize) / 2.0
        let y = (size.height - squareSize) / 2.0
        
        let cropRect = CGRect(
            x: x * scale,
            y: y * scale,
            width: squareSize * scale,
            height: squareSize * scale
        )
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(
            cgImage: cgImage,
            scale: scale,
            orientation: image.imageOrientation
        )
    }
}
