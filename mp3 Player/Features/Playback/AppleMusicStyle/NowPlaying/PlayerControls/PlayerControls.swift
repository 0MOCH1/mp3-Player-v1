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
    
    // Toggle states derived from model.playerMode
    private var lyricsToggled: Bool {
        model.playerMode == .lyrics
    }
    private var queueToggled: Bool {
        model.playerMode == .queue
    }

    var body: some View {
        VStack(spacing: 0) {
            // シークバー
            let indicatorPadding = ViewConst.playerCardPaddings - ElasticSliderConfig.playbackProgress.growth
            TimingIndicator(spacing: 0)
                .padding(.horizontal, indicatorPadding)
            
            // 30pt spacing (seekBar to playerButtons)
            Spacer().frame(height: ViewConst.playerButtonsToSeekBarSpacing-10)
            
            // Player buttons
            PlayerButtons(spacing: 42)
                .padding(.horizontal, ViewConst.playerCardPaddings)
            
            // 30pt spacing (playerButtons to volume)
            Spacer().frame(height: ViewConst.volumeToPlayerButtonsSpacing+10)
            
            // Volume
            VolumeSlider()
                .padding(.horizontal, 8)
            
            // Footer (Lyrics, AirPlay, Queue buttons)
            footer
                .padding(.horizontal, ViewConst.playerCardPaddings)
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

    var footer: some View {
        // Spacing of 80pt between buttons
        HStack(alignment: .center, spacing: 80) {
            // Lyrics button with circle background
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    model.toggleLyrics()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(lyricsToggled ? Color(palette.opaque) : Color(palette.opaque).opacity(0))
                        .frame(width: 40, height: 40)
                        .blendMode(lyricsToggled ? .normal : .overlay)
                    
                    Image(systemName: lyricsToggled ? "quote.bubble.fill" : "quote.bubble")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(lyricsToggled ? .black.opacity(0.6) : Color(palette.opaque))
                        .blendMode(lyricsToggled ? .normal : .overlay)
                }
            }
            
            // AirPlay button - using AVRoutePickerView directly
            AirPlayButton()
                .frame(width: 40, height: 40)
            
            // Queue button with circle background
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    model.toggleQueue()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(queueToggled ? Color(palette.opaque) : Color(palette.opaque).opacity(0))
                        .frame(width: 40, height: 40)
                        .blendMode(queueToggled ? .normal : .overlay)
                    
                    queueButtonIcon
                }
            }
        }
    }
    
    // Queue button with shuffle/repeat indicators
    private var queueButtonIcon: some View {
        ZStack {
            Image(systemName: "list.bullet")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(queueToggled ? .black.opacity(0.6) : Color(palette.opaque))
                .blendMode(queueToggled ? .normal : .overlay)
            
            // Shuffle indicator (top-right)
            if model.isShuffleEnabled {
                Image(systemName: "shuffle")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(queueToggled ? .black.opacity(0.6) : Color(palette.opaque))
                    .offset(x: 12, y: -10)
            }
            
            // Repeat indicator (bottom-right)
            if model.repeatMode != .off {
                Image(systemName: model.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(queueToggled ? .black.opacity(0.6) : Color(palette.opaque))
                    .offset(x: 12, y: 10)
            }
        }
    }
}

