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
            
            // Compact header (visible in S1-S4 per spec 1.1)
            if stateManager.showsCompactHeader {
                CompactTrackInfoView {
                    stateManager.returnToStandard()
                }
                .padding(.horizontal, ViewConst.playerCardPaddings)
                .padding(.top, 12)
            }
            
            // Main content area
            mainContent
            
            // Controls section (visible in S0, S1, S3 per spec 1.2)
            if stateManager.showsControls {
                PlayerControls(stateManager: stateManager, showTrackInfo: !stateManager.showsCompactHeader)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.top, safeArea.top)
        .padding(.bottom, safeArea.bottom)
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
                .transition(.opacity)
            
        case .lyricsSmall, .lyricsLarge:
            // S1/S2: Lyrics view
            LyricsScreenView(stateManager: stateManager)
                .transition(.opacity)
            
        case .queueSmall, .queueReorderLarge:
            // S3/S4: Queue view
            QueueScreenView(stateManager: stateManager)
                .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var standardContent: some View {
        GeometryReader { geo in
            let artworkSize = min(geo.size.width - 50, geo.size.height * 0.6)
            
            VStack {
                Spacer()
                
                // Large artwork (per spec 2.1 S0)
                artwork
                    .frame(width: artworkSize, height: artworkSize)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, size.height < 700 ? 10 : 30)
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
