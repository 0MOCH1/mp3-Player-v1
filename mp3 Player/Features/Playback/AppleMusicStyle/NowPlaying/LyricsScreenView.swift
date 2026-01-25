//
//  LyricsScreenView.swift
//  mp3 Player
//

import SwiftUI

/// Lyrics screen view for states S1 (small) and S2 (large)
/// Shows compact header with scrollable lyrics below
struct LyricsScreenView: View {
    @Environment(NowPlayingAdapter.self) var model
    let stateManager: NowPlayingStateManager
    var size: CGSize
    var safeArea: EdgeInsets
    
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    
    private let headerHeight: CGFloat = NowPlayingStateManager.compactHeaderHeight
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Header
            CompactHeader(stateManager: stateManager)
                .padding(.top, safeArea.top)
            
            // Lyrics Content
            lyricsContent
            
            // Bottom controls (same as standard player)
            bottomControls
                .padding(.bottom, safeArea.bottom)
        }
    }
    
    private var lyricsContent: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let lyrics = model.currentLyrics, !lyrics.isEmpty {
                        ForEach(parseLyrics(lyrics), id: \.self) { line in
                            Text(line)
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.8))
                                .multilineTextAlignment(.leading)
                        }
                    } else {
                        // No lyrics available
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "text.quote")
                                .font(.system(size: 48))
                                .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.4))
                            Text("No Lyrics Available")
                                .font(.headline)
                                .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.6))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height * 0.5)
                    }
                }
                .padding(.horizontal, ViewConst.playerCardPaddings)
                .padding(.top, 20)
                .padding(.bottom, 100)
                .background(
                    GeometryReader { scrollGeo in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: scrollGeo.frame(in: .named("lyricsScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "lyricsScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let delta = value - lastScrollOffset
                scrollOffset = value
                
                // Handle snap between S1 and S2
                if stateManager.currentState == .lyricsSmall && delta < -100 {
                    stateManager.goToLyricsLarge()
                } else if stateManager.currentState == .lyricsLarge && delta > 100 {
                    stateManager.goToLyricsSmall()
                }
                
                lastScrollOffset = value
            }
        }
    }
    
    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Additional lyrics controls (translate, wand)
            if stateManager.currentState == .lyricsSmall {
                HStack {
                    Button {
                        // Translate action
                    } label: {
                        Image(systemName: "character.bubble")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.6))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button {
                        // Magic wand action (karaoke mode?)
                    } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.6))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, ViewConst.playerCardPaddings)
            }
            
            // Seek slider
            TimingIndicator(spacing: 8)
                .padding(.horizontal, ViewConst.playerCardPaddings - ElasticSliderConfig.playbackProgress.growth)
            
            // Playback buttons
            PlayerButtons(spacing: size.width * 0.14)
                .padding(.horizontal, ViewConst.playerCardPaddings)
            
            // Volume slider
            VolumeSlider()
                .padding(.horizontal, 8)
            
            // Footer buttons
            footerButtons
                .padding(.horizontal, ViewConst.playerCardPaddings)
        }
    }
    
    private var footerButtons: some View {
        HStack(alignment: .top, spacing: size.width * 0.18) {
            // Lyrics button (active)
            Button {
                stateManager.toggleLyrics()
            } label: {
                Image(systemName: "quote.bubble.fill")
                    .font(.title2)
                    .foregroundStyle(Color(Palette.playerCard.opaque))
            }
            
            // AirPlay button
            VStack(spacing: 6) {
                AirPlayButton()
            }
            
            // Queue button with shuffle indicator
            ZStack(alignment: .topTrailing) {
                Button {
                    stateManager.goToQueueSmall()
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                }
                
                if model.controller.isShuffleEnabled {
                    Image(systemName: "shuffle")
                        .font(.system(size: 8))
                        .padding(3)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                        .offset(x: 8, y: -4)
                }
            }
        }
        .foregroundStyle(Color(Palette.playerCard.opaque))
        .blendMode(.overlay)
    }
    
    private func parseLyrics(_ lyrics: String) -> [String] {
        lyrics.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
