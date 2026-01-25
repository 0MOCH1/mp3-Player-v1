//
//  PlayerControls.swift
//  mp3 Player
//
//  Created by Alexey Vorobyov on 01.12.2024.
//

import SwiftUI

struct PlayerControls: View {
    @Environment(NowPlayingAdapter.self) var model
    @State private var volume: Double = 0.5
    var stateManager: NowPlayingStateManager? = nil
    var showTrackInfo: Bool = true

    var body: some View {
        GeometryReader {
            let size = $0.size
            let spacing = size.verticalSpacing
            VStack(spacing: 0) {
                if showTrackInfo {
                    VStack(spacing: spacing) {
                        trackInfo
                        let indicatorPadding = ViewConst.playerCardPaddings - ElasticSliderConfig.playbackProgress.growth
                        TimingIndicator(spacing: spacing)
                            .padding(.top, spacing)
                            .padding(.horizontal, indicatorPadding)
                    }
                    .frame(height: size.height / 2.5, alignment: .top)
                } else {
                    // When track info is hidden, just show timing indicator
                    let indicatorPadding = ViewConst.playerCardPaddings - ElasticSliderConfig.playbackProgress.growth
                    TimingIndicator(spacing: spacing)
                        .padding(.horizontal, indicatorPadding)
                        .frame(height: size.height / 4, alignment: .bottom)
                }
                PlayerButtons(spacing: size.width * 0.14)
                    .padding(.horizontal, ViewConst.playerCardPaddings)
                volume(playerSize: size)
                    .frame(height: size.height / 2.5, alignment: .bottom)
            }
        }
    }
}

private extension CGSize {
    var verticalSpacing: CGFloat { height * 0.04 }
}

private extension PlayerControls {
    var palette: Palette.PlayerCard.Type {
        UIColor.palette.playerCard.self
    }

    var trackInfo: some View {
        HStack(alignment: .center, spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                let fade = ViewConst.playerCardPaddings
                let cfg = MarqueeText.Config(leftFade: fade, rightFade: fade)
                MarqueeText(model.display.title, config: cfg)
                    .transformEffect(.identity)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(palette.opaque))
                    .id(model.display.title)
                    .allowsHitTesting(false)
                MarqueeText(model.display.subtitle ?? "", config: cfg)
                    .transformEffect(.identity)
                    .foregroundStyle(Color(palette.opaque))
                    .blendMode(.overlay)
                    .id(model.display.subtitle)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }

    func volume(playerSize: CGSize) -> some View {
        VStack(spacing: playerSize.verticalSpacing) {
            VolumeSlider()
                .padding(.horizontal, 8)

            footer(width: playerSize.width)
                .padding(.top, playerSize.verticalSpacing)
                .padding(.horizontal, ViewConst.playerCardPaddings)
        }
    }

    func footer(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: width * 0.18) {
            // Lyrics button (per spec 3.1)
            Button {
                stateManager?.toggleLyrics()
            } label: {
                ZStack {
                    Image(systemName: "quote.bubble")
                        .font(.title2)
                    
                    // Active indicator when in lyrics mode
                    if stateManager?.isLyricsMode == true {
                        Circle()
                            .fill(Color(palette.opaque))
                            .frame(width: 6, height: 6)
                            .offset(x: 12, y: -12)
                    }
                }
            }
            
            // AirPlay button
            VStack(spacing: 6) {
                Button {} label: {
                    Image(systemName: "airpods.gen3")
                        .font(.title2)
                }
                Text("iPhone's Airpods")
                    .font(.caption)
            }
            
            // Queue button (per spec 3.1, 6.9)
            Button {
                stateManager?.toggleQueue()
            } label: {
                ZStack {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                    
                    // Show shuffle/repeat state on queue button (per spec 6.9)
                    if stateManager != nil {
                        if model.controller.isShuffleEnabled {
                            Image(systemName: "shuffle")
                                .font(.caption2)
                                .offset(x: 10, y: -10)
                        } else if model.controller.repeatMode != .off {
                            Image(systemName: model.controller.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.caption2)
                                .offset(x: 10, y: -10)
                        }
                    }
                }
            }
        }
        .foregroundStyle(Color(palette.opaque))
        .blendMode(.overlay)
    }
}

