//
//  PlayerButtons.swift
//  mp3 Player
//
//  Created by Alexey Vorobyov on 15.12.2024.
//

import SwiftUI

struct PlayerButtons: View {
    @Environment(NowPlayingAdapter.self) var model
    let spacing: CGFloat
    // Increased from 34 to 40 for larger icons
    let imageSize: CGFloat = 40
    @State var backwardAnimationTrigger: PlayerButtonTrigger = .one(bouncing: false)
    @State var forwardAnimationTrigger: PlayerButtonTrigger = .one(bouncing: false)

    var body: some View {
        // Reduced spacing by 15pt as requested
        HStack(spacing: max(spacing - 15, 0)) {
            PlayerButton(
                label: {
                    PlayerButtonLabel(
                        type: model.backwardButton,
                        size: imageSize,
                        animationTrigger: backwardAnimationTrigger
                    )
                },
                onEnded: {
                    backwardAnimationTrigger.toggle(bouncing: true)
                    model.onBackward()
                }
            )

            PlayerButton(
                label: {
                    // Changed from imageSize+8 (48) to imageSize+4 (44) - just slightly larger
                    PlayerButtonLabel(type: model.playPauseButton, size: imageSize + 4)
                },
                onEnded: {
                    model.onPlayPause()
                }
            )

            PlayerButton(
                label: {
                    PlayerButtonLabel(
                        type: model.forwardButton,
                        size: imageSize,
                        animationTrigger: forwardAnimationTrigger
                    )
                },
                onEnded: {
                    forwardAnimationTrigger.toggle(bouncing: true)
                    model.onForward()
                }
            )
        }
        .playerButtonStyle(.expandedPlayer)
    }
}

extension PlayerButtonConfig {
    static var expandedPlayer: Self {
        Self(
            labelColor: .init(Palette.PlayerCard.opaque),
            tint: .init(Palette.PlayerCard.translucent.withAlphaComponent(0.3)),
            pressedColor: .init(Palette.PlayerCard.opaque)
        )
    }
}

