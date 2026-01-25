//
//  QueueControlsView.swift
//  mp3 Player
//
//  Queue controls header with shuffle/repeat buttons
//  Per PLAYING_SCREEN_SPEC.md section 6.7
//  Sticky header that remains visible when QueueControls reaches top
//

import SwiftUI

struct QueueControlsView: View {
    @Environment(NowPlayingAdapter.self) var model
    
    var body: some View {
        HStack(spacing: 24) {
            // Shuffle button
            Button {
                model.controller.isShuffleEnabled.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(
                        model.controller.isShuffleEnabled
                            ? Color(Palette.PlayerCard.opaque)
                            : Color(Palette.PlayerCard.opaque).opacity(0.5)
                    )
            }
            .buttonStyle(.plain)
            
            // Repeat button (3 states per spec 6.7)
            Button {
                cycleRepeatMode()
            } label: {
                repeatIcon
                    .font(.title3)
                    .foregroundStyle(
                        model.controller.repeatMode != .off
                            ? Color(Palette.PlayerCard.opaque)
                            : Color(Palette.PlayerCard.opaque).opacity(0.5)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.5))
    }
    
    @ViewBuilder
    private var repeatIcon: some View {
        switch model.controller.repeatMode {
        case .off:
            Image(systemName: "repeat")
        case .one:
            Image(systemName: "repeat.1")
        case .all:
            Image(systemName: "repeat")
        }
    }
    
    private func cycleRepeatMode() {
        switch model.controller.repeatMode {
        case .off:
            model.controller.repeatMode = .one
        case .one:
            model.controller.repeatMode = .all
        case .all:
            model.controller.repeatMode = .off
        }
    }
}
