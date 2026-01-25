//
//  CompactTrackInfoView.swift
//  mp3 Player
//
//  Compact track info header (48pt) for S1-S4 states
//  Per PLAYING_SCREEN_SPEC.md section 1.1
//

import SwiftUI

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

/// Compact track info for queue list (as scrollable element per spec 1.1)
struct CompactTrackInfoListItem: View {
    @Environment(NowPlayingAdapter.self) var model
    
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
    }
}
