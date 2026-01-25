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
    @State private var showLyrics = false
    @State private var showQueue = false

    var body: some View {
        GeometryReader {
            let size = $0.size
            let spacing = size.verticalSpacing
            VStack(spacing: 0) {
                VStack(spacing: spacing) {
                    trackInfo
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
            // Lyrics button
            Button {
                showLyrics = true
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.title2)
            }
            .sheet(isPresented: $showLyrics) {
                LyricsView()
                    .environment(model)
            }
            
            // AirPlay button
            VStack(spacing: 6) {
                AirPlayButton()
                Text("AirPlay")
                    .font(.caption)
            }
            
            // Queue button
            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2)
            }
            .sheet(isPresented: $showQueue) {
                QueueView()
                    .environment(model)
            }
        }
        .foregroundStyle(Color(palette.opaque))
        .blendMode(.overlay)
    }
}

