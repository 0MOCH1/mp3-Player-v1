//
//  QueueControlsView.swift
//  mp3 Player
//
//  Queue controls row with toggle buttons
//  Based on PLAYING_SCREEN_SPEC.md section 6.7 and reference image S3, SnapB.PNG
//  Toggle style: pill-shaped (capsule) buttons
//

import SwiftUI

struct QueueControlsView: View {
    @Environment(NowPlayingAdapter.self) var model
    
    var body: some View {
        HStack(spacing: 8) {
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
            
            // Continuous playback button (per reference image)
            QueueToggleButton(
                icon: "antenna.radiowaves.left.and.right",
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

/// Pill-shaped toggle button (matches reference image S3, SnapB.PNG)
struct QueueToggleButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(
                    isActive
                        ? Color(Palette.PlayerCard.opaque)
                        : Color(Palette.PlayerCard.opaque).opacity(0.6)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    Capsule()
                        .fill(
                            isActive
                                ? Color(Palette.PlayerCard.opaque).opacity(0.3)
                                : Color(Palette.PlayerCard.opaque).opacity(0.15)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

