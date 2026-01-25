//
//  CompactHeader.swift
//  mp3 Player
//

import SwiftUI

/// Compact header shown in states S1-S4
/// Contains: 48x48 artwork thumbnail, title, artist, and optional action buttons
struct CompactHeader: View {
    @Environment(NowPlayingAdapter.self) var model
    let stateManager: NowPlayingStateManager
    var showsStarButton: Bool = true
    var showsMoreButton: Bool = true
    var onClose: (() -> Void)?
    
    private let headerHeight: CGFloat = NowPlayingStateManager.compactHeaderHeight
    private let artworkSize: CGFloat = NowPlayingStateManager.compactArtworkSize
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork thumbnail (48x48)
            ArtworkImageView(
                artworkUri: model.display.artworkUri,
                cornerRadius: 8,
                contentMode: .fill
            )
            .frame(width: artworkSize, height: artworkSize)
            
            // Title and Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(model.display.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(Palette.playerCard.opaque))
                    .lineLimit(1)
                
                if let subtitle = model.display.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                if showsStarButton {
                    Button {
                        // TODO: Favorite action
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 18))
                    }
                }
                
                if showsMoreButton {
                    Button {
                        // TODO: More options action
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                    }
                }
            }
            .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.8))
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .frame(height: headerHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap header to return to S0
            if let onClose {
                onClose()
            } else {
                stateManager.goToStandard()
            }
        }
    }
}

/// Compact header variant without action buttons, for simpler layouts
struct CompactHeaderSimple: View {
    @Environment(NowPlayingAdapter.self) var model
    let stateManager: NowPlayingStateManager
    var onClose: (() -> Void)?
    
    private let headerHeight: CGFloat = NowPlayingStateManager.compactHeaderHeight
    private let artworkSize: CGFloat = NowPlayingStateManager.compactArtworkSize
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork thumbnail (48x48)
            ArtworkImageView(
                artworkUri: model.display.artworkUri,
                cornerRadius: 8,
                contentMode: .fill
            )
            .frame(width: artworkSize, height: artworkSize)
            
            // Title and Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(model.display.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(Palette.playerCard.opaque))
                    .lineLimit(1)
                
                if let subtitle = model.display.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .frame(height: headerHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            if let onClose {
                onClose()
            } else {
                stateManager.goToStandard()
            }
        }
    }
}
