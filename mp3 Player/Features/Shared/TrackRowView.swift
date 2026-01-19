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
                artworkSize: artworkSize
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
    

    var body: some View {
        ZStack {
            if showsArtwork {
                ArtworkImageView(artworkUri: artworkUri, cornerRadius: 6, contentMode: .fill)
                    .overlay {
                        if isNowPlaying {
                            EqualizerBarsView()
                        }
                    }
            } else {
                if isNowPlaying {
                    EqualizerBarsView()
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

private struct EqualizerBarsView: View {
    @State private var phase = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            EqualizerBarView(phase: phase, minScale: 0.3, maxScale: 0.9, delay: 0.0)
            EqualizerBarView(phase: phase, minScale: 0.5, maxScale: 0.2, delay: 0.08)
            EqualizerBarView(phase: phase, minScale: 0.2, maxScale: 0.8, delay: 0.16)
            EqualizerBarView(phase: phase, minScale: 0.6, maxScale: 0.3, delay: 0.24)
            EqualizerBarView(phase: phase, minScale: 0.4, maxScale: 0.7, delay: 0.32)
        }
        .frame(width: 20, height: 16)
        .onAppear {
            phase.toggle()
        }
    }
}

private struct EqualizerBarView: View {
    let phase: Bool
    let minScale: CGFloat
    let maxScale: CGFloat
    let delay: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(.primary)
            .frame(width: 3, height: 14)
            .scaleEffect(y: phase ? maxScale : minScale, anchor: .bottom)
            .animation(
                .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: phase
            )
    }
}


