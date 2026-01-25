//
//  LyricsScreenView.swift
//  mp3 Player
//
//  Lyrics view for S1 (small) and S2 (large) states
//  Per PLAYING_SCREEN_SPEC.md sections 3.2, 4.1, 5
//

import SwiftUI

struct LyricsScreenView: View {
    @Environment(NowPlayingAdapter.self) var model
    @Bindable var stateManager: NowPlayingStateManager
    
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Threshold for S1 ↔ S2 transition (adjustable per spec 3.2)
    private let transitionThreshold: CGFloat = 100
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                lyricsContent(geometry: geometry)
            }
        }
    }
    
    @ViewBuilder
    private func lyricsContent(geometry: GeometryProxy) -> some View {
        let lyrics = model.controller.currentLyrics
        
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                if let lyrics = lyrics, !lyrics.isEmpty {
                    // Parse and display lyrics lines
                    ForEach(Array(lyrics.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                        if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(line)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.85))
                                .multilineTextAlignment(.leading)
                        }
                    }
                } else {
                    // Placeholder when lyrics not available (per spec 5)
                    lyricsPlaceholder
                }
            }
            .padding(.horizontal, ViewConst.playerCardPaddings)
            .padding(.vertical, 20)
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
            handleScrollChange(offset: value)
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in isDragging = true }
                .onEnded { value in
                    isDragging = false
                    handleDragEnd(translation: value.translation.height)
                }
        )
    }
    
    private var lyricsPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.4))
            
            Text("歌詞がありません")
                .font(.headline)
                .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private func handleScrollChange(offset: CGFloat) {
        scrollOffset = offset
    }
    
    private func handleDragEnd(translation: CGFloat) {
        switch stateManager.currentState {
        case .lyricsSmall:
            // Per spec 3.2: scroll down near top expands to S2
            if scrollOffset > -50 && translation > transitionThreshold {
                stateManager.expandLyrics()
            }
        case .lyricsLarge:
            // Per spec 3.2: scroll up collapses to S1
            if translation < -transitionThreshold {
                stateManager.collapseLyrics()
            }
        default:
            break
        }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
