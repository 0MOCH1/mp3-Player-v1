//
//  LyricsScreenView.swift
//  mp3 Player
//

import SwiftUI

/// Lyrics screen view for states S1 (small) and S2 (large)
/// Per spec section 4.1:
/// - S1: 表示エリア小＝縮小楽曲情報下〜コントロール部上
/// - S2: 表示エリア大＝縮小楽曲情報下〜画面下端（コントロール部非表示）
struct LyricsScreenView: View {
    @Environment(NowPlayingAdapter.self) var model
    let stateManager: NowPlayingStateManager
    var size: CGSize
    var safeArea: EdgeInsets
    
    @State private var scrollOffset: CGFloat = 0
    @State private var isAtTop: Bool = true
    
    private let headerHeight: CGFloat = NowPlayingStateManager.compactHeaderHeight
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Header (fixed at top per spec section 4.1)
            CompactHeader(stateManager: stateManager)
                .padding(.top, safeArea.top)
            
            // Lyrics Content
            lyricsContent
            
            // Bottom controls (shown only in S1, hidden in S2 per spec)
            if stateManager.currentState == .lyricsSmall {
                bottomControls
                    .padding(.bottom, safeArea.bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(NowPlayingStateManager.transitionAnimation, value: stateManager.currentState)
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
                        // No lyrics available - show placeholder per spec section 5
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "text.quote")
                                .font(.system(size: 48))
                                .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.4))
                            Text("歌詞がありません")
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
                            key: LyricsScrollOffsetKey.self,
                            value: scrollGeo.frame(in: .named("lyricsScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "lyricsScroll")
            .onPreferenceChange(LyricsScrollOffsetKey.self) { value in
                scrollOffset = value
                // Check if at top (with small threshold for touch imprecision)
                isAtTop = value >= -10
            }
            // Gesture for S1 ↔ S2 transitions per spec section 3.2
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        handleLyricsDragEnd(value, viewportHeight: geo.size.height)
                    }
            )
        }
    }
    
    /// Handle drag end for S1 ↔ S2 snap transitions
    /// Per spec section 3.2: 歌詞が上端付近のときのみ下方向ジェスチャでS2へ遷移を許可
    private func handleLyricsDragEnd(_ value: DragGesture.Value, viewportHeight: CGFloat) {
        let threshold = NowPlayingStateManager.lyricsSnapThreshold
        let translation = value.translation.height
        
        if stateManager.currentState == .lyricsSmall {
            // S1 → S2: Only allow when at top and scrolling down
            if isAtTop && translation > threshold {
                withAnimation(NowPlayingStateManager.transitionAnimation) {
                    stateManager.goToLyricsLarge()
                }
            }
        } else if stateManager.currentState == .lyricsLarge {
            // S2 → S1: Scroll up to return
            if translation < -threshold {
                withAnimation(NowPlayingStateManager.transitionAnimation) {
                    stateManager.goToLyricsSmall()
                }
            }
        }
    }
    
    private var bottomControls: some View {
        VStack(spacing: 12) {
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
            // Lyrics button (active state indicated by filled icon)
            Button {
                withAnimation(NowPlayingStateManager.transitionAnimation) {
                    stateManager.toggleLyrics()
                }
            } label: {
                Image(systemName: "quote.bubble.fill")
                    .font(.title2)
                    .foregroundStyle(Color(Palette.playerCard.opaque))
            }
            
            // AirPlay button
            VStack(spacing: 6) {
                AirPlayButton()
            }
            
            // Queue button with state indicator per spec section 6.9
            ZStack(alignment: .topTrailing) {
                Button {
                    withAnimation(NowPlayingStateManager.transitionAnimation) {
                        stateManager.goToQueueSmall()
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                }
                
                // Show shuffle/repeat indicator per spec section 6.9
                if model.controller.isShuffleEnabled || model.controller.repeatMode != .off {
                    Image(systemName: model.controller.isShuffleEnabled ? "shuffle" : "repeat")
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

private struct LyricsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
