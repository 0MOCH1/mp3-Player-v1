//
//  AppleMusicNowPlayingView.swift
//  mp3 Player
//

import SwiftUI

struct AppleMusicNowPlayingView: View {
    @Environment(\.playbackController) private var playbackController
    @Environment(\.dismiss) private var dismiss
    @State private var adapter: NowPlayingAdapter?
    @State private var expanded = true
    
    var body: some View {
        ZStack {
            if let adapter {
                StatefulNowPlayingView(
                    onDismiss: { dismiss() }
                )
                .environment(adapter)
            }
        }
        .onAppear {
            if let controller = playbackController {
                adapter = NowPlayingAdapter(controller: controller)
            }
        }
    }
}

/// Main view that switches between different states (S0-S4)
private struct StatefulNowPlayingView: View {
    @Environment(NowPlayingAdapter.self) var model
    @Environment(\.dismiss) private var dismiss
    let onDismiss: () -> Void
    
    @State private var offsetY: CGFloat = 0.0
    @State private var deviceCornerRadius: CGFloat = 39.0
    @State private var currentCornerRadius: CGFloat = 0.0
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let safeArea = geo.safeAreaInsets
            
            // Calculate progressive corner radius based on drag amount
            let dragProgress = min(offsetY / 20.0, 1.0)
            let _ = dragProgress * deviceCornerRadius

            ZStack(alignment: .top) {
                // Background
                NowPlayingBackground(
                    colors: model.colors.map { Color($0.color) },
                    expanded: true,
                    isFullExpanded: true
                )
                
                // State-based content
                stateContent(size: size, safeArea: safeArea)
            }
            .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
            .offset(y: offsetY)
            .gesture(dragGesture(size: size))
            .ignoresSafeArea()
        }
        .background(Color.clear)
        .onAppear {
            model.onAppear()
            // Get the device's actual corner radius
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let screen = windowScene.screen as UIScreen? {
                deviceCornerRadius = screen.displayCornerRadius
            }
        }
    }
    
    @ViewBuilder
    private func stateContent(size: CGSize, safeArea: EdgeInsets) -> some View {
        switch model.stateManager.currentState {
        case .standard:
            StandardPlayerView(
                stateManager: model.stateManager,
                size: size,
                safeArea: safeArea
            )
            
        case .lyricsSmall, .lyricsLarge:
            LyricsScreenView(
                stateManager: model.stateManager,
                size: size,
                safeArea: safeArea
            )
            
        case .queueSmall, .queueReorderLarge:
            QueueScreenView(
                stateManager: model.stateManager,
                size: size,
                safeArea: safeArea
            )
        }
    }
    
    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let translation = max(value.translation.height, 0)
                offsetY = translation
                // Update corner radius immediately during drag
                let dragProgress = min(translation / 20.0, 1.0)
                currentCornerRadius = dragProgress * deviceCornerRadius
            }
            .onEnded { value in
                let translation = max(value.translation.height, 0)
                let velocity = value.velocity.height / 5
                
                // Changed threshold from 0.3 to 0.5 (half the screen)
                if (translation + velocity) > (size.height * 0.5) {
                    // Dismiss - call immediately without animation delay
                    onDismiss()
                } else {
                    // Snap back with animation
                    withAnimation(.spring()) {
                        offsetY = 0
                    }
                    // Delay corner radius removal until animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            currentCornerRadius = 0
                        }
                    }
                }
            }
    }
}
