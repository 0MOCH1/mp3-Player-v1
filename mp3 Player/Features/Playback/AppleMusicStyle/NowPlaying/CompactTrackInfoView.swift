//
//  CompactTrackInfoView.swift
//  mp3 Player
//
//  Compact track info (48pt) for all modes
//  Per PLAYING_SCREEN_SPEC.md section 1.1
//

import SwiftUI

/// Compact track info header (48pt) for all modes - consistent size
struct CompactTrackInfoView: View {
    @Environment(NowPlayingAdapter.self) var model
    let onTap: () -> Void
    
    private let height: CGFloat = 48
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail artwork
            ArtworkImageView(
                artworkUri: model.display.artworkUri,
                cornerRadius: 6,
                contentMode: .fill
            )
            .frame(width: height, height: height)
            
            // Title and artist
            VStack(alignment: .leading, spacing: 2) {
                Text(model.display.title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque))
                    .lineLimit(1)
                
                if let subtitle = model.display.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

/// Compact track info for queue list header (as scrollable element per spec 1.1)
/// Uses same 48pt sizing as lyrics mode for consistency
struct CompactTrackInfoQueueHeader: View {
    @Environment(NowPlayingAdapter.self) var model
    let onTap: () -> Void
    
    private let artworkSize: CGFloat = 48
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork - same size as lyrics mode for consistency
            ArtworkImageView(
                artworkUri: model.display.artworkUri,
                cornerRadius: 6,
                contentMode: .fill
            )
            .frame(width: artworkSize, height: artworkSize)
            .onTapGesture {
                onTap()
            }
            
            // Title and artist
            VStack(alignment: .leading, spacing: 2) {
                Text(model.display.title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque))
                    .lineLimit(1)
                
                if let subtitle = model.display.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Menu button
            Button {
                // Show menu
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 8)
    }
}

