import SwiftUI

struct PlaylistRowView: View {
    let title: String
    let artworkUris: [String?]
    let isFavorite: Bool
    let onMore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            FavoriteIndicatorView(isFavorite: isFavorite)

            PlaylistCollageView(artworkUris: artworkUris)
                .frame(width: 52, height: 52)

            Text(title)
                .lineLimit(1)

            Spacer()

            Button {
                onMore()
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
