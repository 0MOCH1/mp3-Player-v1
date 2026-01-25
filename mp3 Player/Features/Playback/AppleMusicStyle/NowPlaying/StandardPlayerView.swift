//
//  StandardPlayerView.swift
//  mp3 Player
//

import SwiftUI

/// Standard player view (S0 state)
/// Full-size artwork with title/artist below and playback controls
struct StandardPlayerView: View {
    @Environment(NowPlayingAdapter.self) var model
    let stateManager: NowPlayingStateManager
    var size: CGSize
    var safeArea: EdgeInsets
    
    var body: some View {
        VStack(spacing: 12) {
            grip
                .blendMode(.overlay)

            artwork
                .frame(height: size.width - 50)
                .padding(.vertical, size.height < 700 ? 10 : 30)
                .padding(.horizontal, 25)

            playerControls
        }
        .padding(.top, safeArea.top)
        .padding(.bottom, safeArea.bottom)
    }
    
    private var grip: some View {
        Capsule()
            .fill(.white.secondary)
            .frame(width: 40, height: 5)
    }

    private var artwork: some View {
        GeometryReader { geo in
            let artworkSize = geo.size
            // Show smaller when paused, full size when playing
            let isPlaying = model.state == .playing
            ArtworkImageView(artworkUri: model.display.artworkUri, cornerRadius: 10, contentMode: .fill)
                .padding(isPlaying ? 0 : 48)
                .shadow(
                    color: Color(.sRGBLinear, white: 0, opacity: isPlaying ? 0.33 : 0.13),
                    radius: isPlaying ? 8 : 3,
                    y: isPlaying ? 10 : 3
                )
                .frame(width: artworkSize.width, height: artworkSize.height)
                .animation(.smooth, value: model.state)
        }
    }
    
    private var playerControls: some View {
        GeometryReader { geo in
            let controlsSize = geo.size
            let spacing = controlsSize.verticalSpacing
            VStack(spacing: 0) {
                VStack(spacing: spacing) {
                    trackInfo
                    let indicatorPadding = ViewConst.playerCardPaddings - ElasticSliderConfig.playbackProgress.growth
                    TimingIndicator(spacing: spacing)
                        .padding(.top, spacing)
                        .padding(.horizontal, indicatorPadding)
                }
                .frame(height: controlsSize.height / 2.5, alignment: .top)
                
                PlayerButtons(spacing: controlsSize.width * 0.14)
                    .padding(.horizontal, ViewConst.playerCardPaddings)
                
                volume(playerSize: controlsSize)
                    .frame(height: controlsSize.height / 2.5, alignment: .bottom)
            }
        }
    }
    
    private var trackInfo: some View {
        HStack(alignment: .center, spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                let fade = ViewConst.playerCardPaddings
                let cfg = MarqueeText.Config(leftFade: fade, rightFade: fade)
                MarqueeText(model.display.title, config: cfg)
                    .transformEffect(.identity)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(Palette.playerCard.opaque))
                    .id(model.display.title)
                    .allowsHitTesting(false)
                MarqueeText(model.display.subtitle ?? "", config: cfg)
                    .transformEffect(.identity)
                    .foregroundStyle(Color(Palette.playerCard.opaque))
                    .blendMode(.overlay)
                    .id(model.display.subtitle)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }
    
    private func volume(playerSize: CGSize) -> some View {
        VStack(spacing: playerSize.verticalSpacing) {
            VolumeSlider()
                .padding(.horizontal, 8)

            footer(width: playerSize.width)
                .padding(.top, playerSize.verticalSpacing)
                .padding(.horizontal, ViewConst.playerCardPaddings)
        }
    }

    private func footer(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: width * 0.18) {
            // Lyrics button
            Button {
                stateManager.goToLyricsSmall()
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.title2)
            }
            
            // AirPlay button
            VStack(spacing: 6) {
                AirPlayButton()
                Text("AirPlay")
                    .font(.caption)
            }
            
            // Queue button
            Button {
                stateManager.goToQueueSmall()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2)
            }
        }
        .foregroundStyle(Color(Palette.playerCard.opaque))
        .blendMode(.overlay)
    }
}

private extension CGSize {
    var verticalSpacing: CGFloat { height * 0.04 }
}
