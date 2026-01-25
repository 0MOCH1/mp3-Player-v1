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
                        // Reduced from spacing to spacing-10
                        .padding(.top, spacing - 10)
                        .padding(.horizontal, indicatorPadding)
                }
                .frame(height: size.height / 2.5, alignment: .top)
                // Player buttons with increased spacing for wider controls
                PlayerButtons(spacing: size.width * 0.14 + 10)
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
                // Title: title2, bold
                MarqueeText(model.display.title, config: cfg)
                    .transformEffect(.identity)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(palette.opaque))
                    .id(model.display.title)
                    .allowsHitTesting(false)
                // Artist: title3
                MarqueeText(model.display.subtitle ?? "", config: cfg)
                    .transformEffect(.identity)
                    .font(.title3)
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
        VStack(spacing: playerSize.verticalSpacing + 10) {
            VolumeSlider()
                .padding(.horizontal, 8)

            footer(width: playerSize.width)
                // Reduced spacing from verticalSpacing to verticalSpacing-20
                .padding(.top, playerSize.verticalSpacing - 20)
                // Increased bottom padding by 15pt
                .padding(.bottom, 15)
                .padding(.horizontal, ViewConst.playerCardPaddings)
        }
    }

    func footer(width: CGFloat) -> some View {
        // Reduced spacing from 0.18 to 0.12 for tighter button arrangement
        HStack(alignment: .center, spacing: width * 0.12) {
            // Lyrics button
            Button {
                showLyrics = true
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 20, weight: .semibold))
            }
            .sheet(isPresented: $showLyrics) {
                LyricsView()
                    .environment(model)
            }
            
            // AirPlay button - using center alignment to ignore text height
            Button {
                // AirPlay button action handled by AVRoutePickerView
            } label: {
                VStack(spacing: 0) {
                    AirPlayButton()
                        .frame(height: 20)
                }
            }
            .disabled(true) // Disable button, let AVRoutePickerView handle interaction
            
            // Queue button
            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .semibold))
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

