//
//  QueueControlsView.swift
//  mp3 Player
//

import SwiftUI

/// Queue control buttons: Shuffle, Repeat, Infinity (autoplay), and Queue mode toggle
/// This appears as a sticky header in the queue screen (S3/S4)
struct QueueControlsView: View {
    @Environment(NowPlayingAdapter.self) var model
    
    var body: some View {
        HStack(spacing: 8) {
            // Shuffle button
            QueueControlButton(
                icon: "shuffle",
                isActive: model.controller.isShuffleEnabled,
                action: {
                    model.controller.isShuffleEnabled.toggle()
                }
            )
            
            // Repeat button
            QueueControlButton(
                icon: repeatIcon,
                isActive: model.controller.repeatMode != .off,
                action: {
                    cycleRepeatMode()
                }
            )
            
            // Infinity/Autoplay button
            QueueControlButton(
                icon: "infinity",
                isActive: false, // TODO: Implement autoplay state
                action: {
                    // TODO: Toggle autoplay
                }
            )
            
            // Queue mode button (for now, just a visual toggle)
            QueueControlButton(
                icon: "quote.bubble",
                isActive: false,
                action: {
                    // TODO: Toggle queue mode
                }
            )
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 8)
    }
    
    private var repeatIcon: String {
        switch model.controller.repeatMode {
        case .off, .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }
    
    private func cycleRepeatMode() {
        switch model.controller.repeatMode {
        case .off:
            model.controller.repeatMode = .all
        case .all:
            model.controller.repeatMode = .one
        case .one:
            model.controller.repeatMode = .off
        }
    }
}

/// Individual queue control button with active/inactive states
struct QueueControlButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? .white : Color(Palette.playerCard.opaque).opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    Capsule()
                        .fill(isActive ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}
