//
//  QueueControlsView.swift
//  mp3 Player
//
//  Queue controls row with toggle buttons
//  Based on reference image S3, SnapB.PNG
//  Shows: Shuffle, Repeat, Autoplay (infinity), and another toggle
//

import SwiftUI

struct QueueControlsView: View {
    @Environment(NowPlayingAdapter.self) var model
    
    var body: some View {
        HStack(spacing: 12) {
            // Shuffle button
            QueueToggleButton(
                icon: "shuffle",
                isActive: model.controller.isShuffleEnabled
            ) {
                model.controller.isShuffleEnabled.toggle()
            }
            
            // Repeat button
            QueueToggleButton(
                icon: repeatIconName,
                isActive: model.controller.repeatMode != .off
            ) {
                cycleRepeatMode()
            }
            
            // Autoplay (infinity) button
            QueueToggleButton(
                icon: "infinity",
                isActive: false  // TODO: Connect to autoplay state
            ) {
                // Toggle autoplay
            }
            
            // Continuous playback button
            QueueToggleButton(
                icon: "goforward",
                isActive: false  // TODO: Connect to continuous playback state
            ) {
                // Toggle continuous playback
            }
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 12)
    }
    
    private var repeatIconName: String {
        switch model.controller.repeatMode {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
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

struct QueueToggleButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(
                    isActive
                        ? Color(Palette.PlayerCard.opaque)
                        : Color(Palette.PlayerCard.opaque).opacity(0.6)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isActive
                                ? Color(Palette.PlayerCard.opaque).opacity(0.25)
                                : Color(Palette.PlayerCard.opaque).opacity(0.1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

