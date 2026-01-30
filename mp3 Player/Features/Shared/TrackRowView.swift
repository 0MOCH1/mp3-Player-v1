import SwiftUI

struct TrackRowView: View {
    let title: String
    let subtitle: String?
    let artworkUri: String?
    let trackNumber: Int?
    let isFavorite: Bool
    let isNowPlaying: Bool
    let showsArtwork: Bool
    let onPlay: () -> Void
    let onMore: () -> Void
    @EnvironmentObject private var playbackController: PlaybackController
    
    private let artworkSize: CGFloat = 48
    private let numberColumnWidth: CGFloat = 24
    private let rowVPad: CGFloat = 4
    private let hGap: CGFloat = 0

    var body: some View {
        HStack(spacing: hGap) {
            FavoriteIndicatorView(isFavorite: isFavorite)

            TrackLeadingView(
                artworkUri: artworkUri,
                trackNumber: trackNumber,
                isNowPlaying: isNowPlaying,
                showsArtwork: showsArtwork,
                artworkSize: artworkSize,
                visualizerLevels: playbackController.visualizerLevels
            )
            .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()

            Button {
                onMore()
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.primary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 26)
        }
        .padding(.vertical, rowVPad)
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
    }
}

private struct TrackLeadingView: View {
    let artworkUri: String?
    let trackNumber: Int?
    let isNowPlaying: Bool
    let showsArtwork: Bool
    let artworkSize: CGFloat
    let visualizerLevels: [CGFloat]
    

    var body: some View {
        ZStack {
            if showsArtwork {
                ArtworkImageView(artworkUri: artworkUri, cornerRadius: 6, contentMode: .fill)
                    .overlay {
                        if isNowPlaying {
                            TrackRowVisualizerView(levels: visualizerLevels)
                        }
                    }
            } else {
                if isNowPlaying {
                    TrackRowVisualizerView(levels: visualizerLevels)
                } else {
                    Text(trackNumber.map(String.init) ?? "-")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: artworkSize, height: artworkSize)
        .clipped()
    }
}

private struct TrackRowVisualizerView: View {
    let levels: [CGFloat]

    var body: some View {
        let normalizedLevels = normalizedLevels(for: levels)

        ZStack {
            Color.black.opacity(0.35)
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(normalizedLevels.indices, id: \.self) { index in
                    let height = max(2, 16 * normalizedLevels[index])
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 2, height: height)
                }
            }
            .animation(.easeOut(duration: 0.12), value: levels)
        }
    }

    private func normalizedLevels(for levels: [CGFloat]) -> [CGFloat] {
        let clamped = levels.map { min(max($0, 0), 1) }
        if clamped.count >= 5 {
            return Array(clamped.prefix(5))
        }
        return clamped + Array(repeating: 0, count: 5 - clamped.count)
    }
}
