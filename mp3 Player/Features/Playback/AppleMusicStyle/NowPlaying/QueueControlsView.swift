//
//  QueueControlsView.swift
//  mp3 Player
//
//  Queue controls row with toggle buttons
//  Based on PLAYING_SCREEN_SPEC.md section 6.7
//  Toggle style: filled circle cutout (like S1/S2 lyrics button)
//

import SwiftUI

struct QueueControlsView: View {
    @Environment(NowPlayingAdapter.self) var model
    
    var body: some View {
        HStack(spacing: 12) {
            // Shuffle button
            QueueToggleButton(
                iconNormal: "shuffle",
                iconActive: "shuffle",
                isActive: model.controller.isShuffleEnabled
            ) {
                model.controller.isShuffleEnabled.toggle()
            }
            
            // Repeat button
            QueueToggleButton(
                iconNormal: "repeat",
                iconActive: repeatIconName,
                isActive: model.controller.repeatMode != .off
            ) {
                cycleRepeatMode()
            }
            
            // Autoplay (infinity) button
            QueueToggleButton(
                iconNormal: "infinity",
                iconActive: "infinity",
                isActive: false  // TODO: Connect to autoplay state
            ) {
                // Toggle autoplay
            }
            
            // Continuous playback button
            QueueToggleButton(
                iconNormal: "goforward",
                iconActive: "goforward",
                isActive: false  // TODO: Connect to continuous playback state
            ) {
                // Toggle continuous playback
            }
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 8)
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

/// Toggle button with filled circle cutout style (matches S1/S2 lyrics button)
struct QueueToggleButton: View {
    let iconNormal: String
    let iconActive: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background circle - visible when active
                if isActive {
                    Circle()
                        .fill(Color(Palette.PlayerCard.opaque))
                        .frame(width: 36, height: 36)
                }
                
                // Icon - filled version for active, regular for inactive
                Image(systemName: isActive ? iconActive : iconNormal)
                    .font(.body.weight(.medium))
                    .foregroundStyle(
                        isActive
                            ? Color(Palette.PlayerCard.opaque).opacity(0.1) // Dark for contrast on light circle
                            : Color(Palette.PlayerCard.opaque).opacity(0.6)
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
        }
        .buttonStyle(.plain)
    }
}

