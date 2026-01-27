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
    var animation: Namespace.ID
    let controlsHeight: CGFloat
    
    // スクロール位置によるControlsVisibility切り替え用
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    
    private let compactTrackInfoHeight: CGFloat = 100
    private let edgeFadeHeight: CGFloat = 40
    
    // 実際のControls高さ（Visibility考慮）- v7仕様に基づき動的に変更
    private var effectiveControlsHeight: CGFloat {
        model.controlsVisibility == .shown ? controlsHeight + safeArea.bottom + ViewConst.bottomToFooterPadding : 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Grip用のスペーサー（GripはLayer0で描画される）
            Spacer()
                .frame(height: ViewConst.gripSpaceHeight)
                .padding(.top, safeArea.top)
            
            // CompactTrackInfo（固定ヘッダ）- matchedGeometryEffect適用
            // 10pt上に配置
            CompactTrackInfoView(animation: animation)
                .padding(.horizontal, 20)
                .padding(.top, ViewConst.contentTopPadding + ViewConst.compactTrackInfoTopOffset)
            
            // LyricsPanel本体（スクロール可能）
            // ControlsVisibility=Shown時: シークバー上端まで
            // ControlsVisibility=Hidden時: 画面下端まで
            lyricsScrollView
                .mask(edgeFadeMask)
                .padding(.bottom, effectiveControlsHeight)
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
            }
        }
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
    var animation: Namespace.ID? = nil
    
    // v8仕様: CompactTrackInfo の Artwork サイズは 72pt
    private let artworkSize: CGFloat = 72
    private let buttonSize: CGFloat = 32
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork (72pt, 正方形, RoundedRectangle) - matchedGeometryEffect適用
            if let animation = animation {
                ArtworkImageView(
                    artworkUri: model.display.artworkUri,
                    cornerRadius: 8,
                    contentMode: .fill
                )
                .frame(width: artworkSize, height: artworkSize)
                .matchedGeometryEffect(id: "artwork", in: animation)
            } else {
                ArtworkImageView(
                    artworkUri: model.display.artworkUri,
                    cornerRadius: 8,
                    contentMode: .fill
                )
                .frame(width: artworkSize, height: artworkSize)
            }
            
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
            
            // AddFavoriteButton (32pt circle, star/star.fill toggle)
            Button {
                model.toggleFavorite()
            } label: {
                Image(systemName: model.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.15))
                    )
            }
            
            // MenuButton (32pt circle, ellipsis)
            Button {
                // TODO: Show menu
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.15))
                    )
            }
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
