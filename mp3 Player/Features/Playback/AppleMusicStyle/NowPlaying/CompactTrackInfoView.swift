//
//  CompactTrackInfoView.swift
//  mp3 Player
//
//  Compact track info for queue mode (S3/S4)
//  Based on reference image S3, SnapB.PNG
//

import SwiftUI

/// Compact track info for queue list header (as scrollable element per spec 1.1)
/// Shows larger artwork (~100pt), title, artist, star button, and menu button
struct CompactTrackInfoQueueHeader: View {
    @Environment(NowPlayingAdapter.self) var model
    let onTap: () -> Void
    
    private let artworkSize: CGFloat = 100
    
    var body: some View {
        HStack(spacing: 16) {
            // Larger artwork for queue mode
            ArtworkImageView(
                artworkUri: model.display.artworkUri,
                cornerRadius: 8,
                contentMode: .fill
            )
            .frame(width: artworkSize, height: artworkSize)
            .onTapGesture {
                onTap()
            }
            
            // Title and artist
            VStack(alignment: .leading, spacing: 4) {
                Text(model.display.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque))
                    .lineLimit(1)
                
                if let subtitle = model.display.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Star (favorite) button
            Button {
                // Toggle favorite
            } label: {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.8))
            }
            .buttonStyle(.plain)
            
            // Menu button
            Button {
                // Show menu
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.8))
                    .padding(12)
                    .background(Color(Palette.PlayerCard.opaque).opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 16)
    }
}

/// Compact track info header (48pt) for lyrics mode (S1/S2)
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

