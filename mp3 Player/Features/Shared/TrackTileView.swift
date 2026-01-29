import SwiftUI

struct TrackTileView: View {
    let title: String
    let artist: String?
    let artworkUri: String?
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkImageView(artworkUri: artworkUri, cornerRadius: 0, contentMode: .fill)
                .aspectRatio(1, contentMode: .fit)

            HStack(spacing: 6) {
                Text(title)
                    .lineLimit(1)
                Spacer()
                FavoriteIndicatorView(isFavorite: isFavorite)
            }

            if let artist {
                Text(artist)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
