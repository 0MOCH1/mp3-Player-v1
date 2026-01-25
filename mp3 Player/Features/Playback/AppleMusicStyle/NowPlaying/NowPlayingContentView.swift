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
    var size: CGSize
    var safeArea: EdgeInsets
    
    var body: some View {
        VStack(spacing: 0) {
            // Grip indicator
            grip
                .blendMode(.overlay)
                .padding(.top, 8)
            
            // Compact header (visible only in lyrics mode S1/S2 per spec 1.1)
            // Queue mode has its own header in the scrollable list
            if stateManager.isLyricsMode {
                CompactTrackInfoView {
                    stateManager.returnToStandard()
                }
                .padding(.horizontal, ViewConst.playerCardPaddings)
                .padding(.top, 12)
            }
            
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: stateManager.currentState)
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
            // S1/S2: Lyrics view
            LyricsScreenView(stateManager: stateManager)
            
        case .queueSmall, .queueReorderLarge:
            // S3/S4: Queue view
            QueueScreenView(stateManager: stateManager)
        }
    }
    
    @ViewBuilder
    private var standardContent: some View {
        // S0: Standard state with large artwork (same as original)
        artwork
            .frame(height: size.width - 50)
            .padding(.vertical, size.height < 700 ? 10 : 30)
            .padding(.horizontal, 25)
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
