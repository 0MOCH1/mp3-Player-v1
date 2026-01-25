//
//  CompactHeader.swift
//  mp3 Player
//

import SwiftUI

/// Compact header showing artwork thumbnail + title/artist (48pt height)
/// Per spec: サムネイル＋タイトルの横並び表示。高さ：固定 48pt
/// Tappable to return to S0 (standard state)
struct CompactHeader: View {
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
            // Tap header to return to S0 (spec section 3.1: 縮小サムネイルをタップ → S0)
            withAnimation(NowPlayingStateManager.transitionAnimation) {
                if let onClose {
                    onClose()
                } else {
                    stateManager.goToStandard()
                }
            }
        }
    }
}
