import SwiftUI
import UIKit

struct ArtworkImageView: View {
    let artworkUri: String?
    var cornerRadius: CGFloat = 0
    var contentMode: ContentMode = .fill
    var placeholderSystemImage: String = "music.note"
    
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
                artworkImage(image)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: placeholderSystemImage)
                    .foregroundStyle(.secondary)
            }
        }
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

    @ViewBuilder
    private func artworkImage(_ image: Image) -> some View {
        if contentMode == .fill {
            image.resizable().scaledToFill()
        } else {
            image.resizable().scaledToFit()
        }
    }

    private func loadImage() async -> Image? {
        guard let artworkUri, let url = URL(string: artworkUri) else { return nil }
        let data = await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value
        guard let data, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
}
