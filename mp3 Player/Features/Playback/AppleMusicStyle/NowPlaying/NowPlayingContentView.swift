//
//  NowPlayingContentView.swift
//  mp3 Player
//
//  Main coordinator view for NowPlaying screen states S0-S4
//  Per PLAYING_SCREEN_SPEC.md section 0 design principles
//

import SwiftUI

struct NowPlayingContentView: View {
    @Environment(NowPlayingAdapter.self) var model
    @State private var stateManager = NowPlayingStateManager()
    @Namespace private var artworkTransition
    var size: CGSize
    var safeArea: EdgeInsets
    
    var body: some View {
        VStack(spacing: 0) {
            // Grip indicator
            grip
                .blendMode(.overlay)
                .padding(.top, 8)
            
            // Main content area - takes all available space
            mainContent
                .frame(maxHeight: .infinity)
            
            // Controls section (visible in S0, S1, S3 per spec 1.2)
            if stateManager.showsControls {
                PlayerControls(stateManager: stateManager, showTrackInfo: stateManager.currentState == .standard)
            }
        }
        .padding(.top, safeArea.top)
        .padding(.bottom, safeArea.bottom)
        .animation(.smooth(duration: 0.35), value: stateManager.currentState)
        .environment(stateManager)
    }
    
    private var grip: some View {
        Capsule()
            .fill(.white.secondary)
            .frame(width: 40, height: 5)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch stateManager.currentState {
        case .standard:
            // S0: Standard state with large artwork
            standardContent
            
        case .lyricsSmall, .lyricsLarge:
            // S1/S2: Lyrics view with compact header
            VStack(spacing: 0) {
                CompactTrackInfoViewAnimated(
                    namespace: artworkTransition,
                    onTap: { stateManager.returnToStandard() }
                )
                .padding(.horizontal, ViewConst.playerCardPaddings)
                .padding(.top, 12)
                
                LyricsScreenView(stateManager: stateManager)
            }
            
        case .queueSmall, .queueReorderLarge:
            // S3/S4: Queue view (has its own header in scroll list)
            QueueScreenView(stateManager: stateManager)
        }
    }
    
    @ViewBuilder
    private var standardContent: some View {
        VStack(spacing: 12) {
            // S0: Standard state with large artwork (same as original)
            artwork
                .matchedGeometryEffect(id: "artwork", in: artworkTransition)
                .frame(height: size.width - 50)
                .padding(.vertical, size.height < 700 ? 10 : 30)
                .padding(.horizontal, 25)
        }
    }
    
    private var artwork: some View {
        GeometryReader { geo in
            let isPlaying = model.state == .playing
            ArtworkImageView(
                artworkUri: model.display.artworkUri,
                cornerRadius: 10,
                contentMode: .fill
            )
            .padding(isPlaying ? 0 : 48)
            .shadow(
                color: Color(.sRGBLinear, white: 0, opacity: isPlaying ? 0.33 : 0.13),
                radius: isPlaying ? 8 : 3,
                y: isPlaying ? 10 : 3
            )
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.smooth, value: model.state)
        }
    }
}

/// Compact track info with matched geometry for smooth transitions
struct CompactTrackInfoViewAnimated: View {
    @Environment(NowPlayingAdapter.self) var model
    let namespace: Namespace.ID
    let onTap: () -> Void
    
    private let height: CGFloat = 48
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail artwork with matched geometry
            ArtworkImageView(
                artworkUri: model.display.artworkUri,
                cornerRadius: 6,
                contentMode: .fill
            )
            .frame(width: height, height: height)
            .matchedGeometryEffect(id: "artwork", in: namespace)
            
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

// Environment key for state manager
private struct NowPlayingStateManagerKey: EnvironmentKey {
    static let defaultValue: NowPlayingStateManager? = nil
}

extension EnvironmentValues {
    var nowPlayingStateManager: NowPlayingStateManager? {
        get { self[NowPlayingStateManagerKey.self] }
        set { self[NowPlayingStateManagerKey.self] = newValue }
    }
}
