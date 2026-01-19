import SwiftUI

struct PlaylistTileView: View {
    let title: String
    let artworkUris: [String?]
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PlaylistCollageView(artworkUris: artworkUris)
                .aspectRatio(1, contentMode: .fit)

            HStack(spacing: 6) {
                Text(title)
                    .lineLimit(1)
                Spacer()
                FavoriteIndicatorView(isFavorite: isFavorite)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
