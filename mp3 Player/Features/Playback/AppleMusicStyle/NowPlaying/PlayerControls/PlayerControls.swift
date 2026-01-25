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
    // Toggle states for lyrics and queue buttons
    @State private var lyricsToggled = false
    @State private var queueToggled = false

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
            // Reduced VStack spacing from 4 to -1 (5pt reduction)
            VStack(alignment: .leading, spacing: -1) {
                let fade = ViewConst.playerCardPaddings
                let cfg = MarqueeText.Config(leftFade: fade, rightFade: fade)
                // Title: title2, semibold (changed from bold)
                MarqueeText(model.display.title, config: cfg)
                    .transformEffect(.identity)
                    .font(.title2)
                    .fontWeight(.semibold)
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
                // Reduced spacing: verticalSpacing-30 (10pt closer)
                .padding(.top, playerSize.verticalSpacing - 30)
                // Reduced bottom padding to 25pt (10pt less)
                .padding(.bottom, 25)
                .padding(.horizontal, ViewConst.playerCardPaddings)
        }
    }

    func footer(width: CGFloat) -> some View {
        // Spacing of 80pt between buttons (20pt wider)
        HStack(alignment: .center, spacing: 80) {
            // Lyrics button with circle background
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    lyricsToggled.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(lyricsToggled ? Color(palette.opaque) : Color(palette.opaque).opacity(0))
                        .frame(width: 44, height: 44)
                        .blendMode(lyricsToggled ? .normal : .overlay)
                    
                    Image(systemName: lyricsToggled ? "quote.bubble.fill" : "quote.bubble")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(lyricsToggled ? Color(palette.transparent) : Color(palette.opaque))
                        .blendMode(lyricsToggled ? .normal : .overlay)
                }
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
            
            // Queue button with circle background
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    queueToggled.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(queueToggled ? Color(palette.opaque) : Color(palette.opaque).opacity(0))
                        .frame(width: 44, height: 44)
                        .blendMode(queueToggled ? .normal : .overlay)
                    
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(queueToggled ? Color(palette.transparent) : Color(palette.opaque))
                        .blendMode(queueToggled ? .normal : .overlay)
                }
            }
        }
    }
}

