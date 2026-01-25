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
                // Always use the same structure for consistent positioning
                VStack(spacing: spacing) {
                    if showTrackInfo {
                        trackInfo
                    } else {
                        // Empty space to maintain consistent layout
                        Color.clear.frame(height: 44)
                    }
                    let indicatorPadding = ViewConst.playerCardPaddings - ElasticSliderConfig.playbackProgress.growth
                    TimingIndicator(spacing: spacing)
                        .padding(.top, spacing)
                        .padding(.horizontal, indicatorPadding)
                }
                .frame(height: size.height / 2.5, alignment: .top)
                
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
            // Lyrics button with filled circle cutout toggle
            Button {
                stateManager?.toggleLyrics()
            } label: {
                ZStack {
                    if stateManager?.isLyricsMode == true {
                        // Active state: filled circle with icon
                        Circle()
                            .fill(Color(palette.opaque))
                            .frame(width: 28, height: 28)
                        Image(systemName: "quote.bubble.fill")
                            .font(.body)
                            .foregroundStyle(Color(palette.opaque).opacity(0.15))
                            .blendMode(.destinationOut)
                    } else {
                        Image(systemName: "quote.bubble")
                            .font(.title2)
                    }
                }
                .compositingGroup()
            }
            // AirPlay button - without static label
            VStack(spacing: 6) {
                AirPlayButton()
                    .frame(width: 24, height: 24)
            }
            // Queue button with filled circle cutout toggle
            Button {
                stateManager?.toggleQueue()
            } label: {
                ZStack {
                    if stateManager?.isQueueMode == true {
                        // Active state: filled circle with icon
                        Circle()
                            .fill(Color(palette.opaque))
                            .frame(width: 28, height: 28)
                        Image(systemName: "list.bullet")
                            .font(.body)
                            .foregroundStyle(Color(palette.opaque).opacity(0.15))
                            .blendMode(.destinationOut)
                    } else {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                    }
                    // Show shuffle/repeat state on queue button (per spec 6.9)
                    if stateManager != nil && stateManager?.isQueueMode != true {
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
                .compositingGroup()
            }
        }
        .foregroundStyle(Color(palette.opaque))
        .blendMode(.overlay)
    }
}

