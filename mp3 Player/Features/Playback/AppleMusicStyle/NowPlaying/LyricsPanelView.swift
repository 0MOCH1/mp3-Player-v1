//
//  LyricsPanelView.swift
//  mp3 Player
//
//  FullPlayer内のLyricsモードで表示される歌詞パネル
//  Layer1: ContentPanel に属する
//

import SwiftUI

struct LyricsPanelView: View {
    @Environment(NowPlayingAdapter.self) var model
    let size: CGSize
    let safeArea: EdgeInsets
    
    // スクロール位置によるControlsVisibility切り替え用
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    
    private let compactTrackInfoHeight: CGFloat = 100
    private let edgeFadeHeight: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            // Grip用のスペーサー（GripはLayer0で描画される）
            Spacer()
                .frame(height: ViewConst.gripSpaceHeight)
                .padding(.top, safeArea.top)
            
            // CompactTrackInfo（固定ヘッダ）
            CompactTrackInfoView()
                .padding(.horizontal, 20)
                .padding(.top, ViewConst.contentTopPadding)
            
            // LyricsPanel本体（スクロール可能）
            lyricsScrollView
                .mask(edgeFadeMask)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var lyricsScrollView: some View {
        GeometryReader { outerGeometry in
            ScrollView {
                lyricsContent
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("lyricsScroll")).minY
                            )
                        }
                    )
            }
            .coordinateSpace(name: "lyricsScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                handleScrollChange(offset)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var lyricsContent: some View {
        Group {
            if let lyrics = model.currentLyrics, !lyrics.isEmpty {
                Text(lyrics)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 20)
                    .padding(.bottom, controlsBottomPadding)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Lyrics not available")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .padding(.bottom, controlsBottomPadding)
            }
        }
    }
    
    // Controls表示時は下部にパディングを追加
    private var controlsBottomPadding: CGFloat {
        model.controlsVisibility == .shown ? 280 : 60
    }
    
    // EdgeFade効果用のマスク
    private var edgeFadeMask: some View {
        VStack(spacing: 0) {
            // 上部のフェード
            LinearGradient(
                colors: [.clear, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: edgeFadeHeight)
            
            // 中央は完全表示
            Rectangle()
                .fill(.white)
            
            // 下部のフェード
            LinearGradient(
                colors: [.white, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: edgeFadeHeight)
        }
    }
    
    private func handleScrollChange(_ offset: CGFloat) {
        let delta = offset - lastScrollOffset
        lastScrollOffset = offset
        
        // 閾値を設けて誤作動を防止
        let threshold: CGFloat = 10
        
        if delta < -threshold {
            // 下方向スクロール → Controls非表示
            model.setControlsVisibility(.hidden)
        } else if delta > threshold {
            // 上方向スクロール → Controls表示
            model.setControlsVisibility(.shown)
        }
    }
}

// MARK: - CompactTrackInfo

struct CompactTrackInfoView: View {
    @Environment(NowPlayingAdapter.self) var model
    
    private let artworkSize: CGFloat = 80
    
    var body: some View {
        HStack(spacing: 16) {
            // Artwork (80pt, 正方形)
            ArtworkImageView(
                artworkUri: model.display.artworkUri,
                cornerRadius: 8,
                contentMode: .fill
            )
            .frame(width: artworkSize, height: artworkSize)
            
            // Title + Artist
            VStack(alignment: .leading, spacing: 4) {
                Text(model.display.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if let subtitle = model.display.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - ScrollOffset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
