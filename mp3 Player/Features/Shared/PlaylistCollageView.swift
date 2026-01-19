import SwiftUI

struct PlaylistCollageView: View {
    let artworkUris: [String?]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            collageBody(size: size)
                .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func collageBody(size: CGFloat) -> some View {
        let items = Array(artworkUris.prefix(4))
        let spacing: CGFloat = 2
        let half = (size - spacing) / 2

        switch items.count {
        case 0:
            ArtworkImageView(artworkUri: nil, cornerRadius: 0, contentMode: .fill)
        case 1:
            ArtworkImageView(artworkUri: items[0], cornerRadius: 0, contentMode: .fill)
        case 2:
            HStack(spacing: spacing) {
                ArtworkImageView(artworkUri: items[0], cornerRadius: 0, contentMode: .fill)
                    .frame(width: half, height: size)
                ArtworkImageView(artworkUri: items[1], cornerRadius: 0, contentMode: .fill)
                    .frame(width: half, height: size)
            }
        case 3:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    ArtworkImageView(artworkUri: items[0], cornerRadius: 0, contentMode: .fill)
                        .frame(width: half, height: half)
                    ArtworkImageView(artworkUri: items[1], cornerRadius: 0, contentMode: .fill)
                        .frame(width: half, height: half)
                }
                ArtworkImageView(artworkUri: items[2], cornerRadius: 0, contentMode: .fill)
                    .frame(width: size, height: half)
            }
        default:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    ArtworkImageView(artworkUri: items[0], cornerRadius: 0, contentMode: .fill)
                        .frame(width: half, height: half)
                    ArtworkImageView(artworkUri: items[1], cornerRadius: 0, contentMode: .fill)
                        .frame(width: half, height: half)
                }
                HStack(spacing: spacing) {
                    ArtworkImageView(artworkUri: items[2], cornerRadius: 0, contentMode: .fill)
                        .frame(width: half, height: half)
                    ArtworkImageView(artworkUri: items[3], cornerRadius: 0, contentMode: .fill)
                        .frame(width: half, height: half)
                }
            }
        }
    }
}
