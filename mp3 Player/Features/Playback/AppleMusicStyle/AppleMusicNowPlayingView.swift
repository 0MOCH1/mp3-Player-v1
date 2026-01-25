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

/// Main view that switches between different states (S0-S4) with smooth transitions
/// Per spec section 0: 状態切替は**スナップ＋アニメーション**で表現する
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
                
                // State-based content with smooth transitions
                // Per spec section 7: 状態遷移はアニメーションあり
                stateContent(size: size, safeArea: safeArea)
                    .animation(NowPlayingStateManager.transitionAnimation, value: model.stateManager.currentState)
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
        // Use ZStack with transitions for smooth state changes
        // Per spec section 0: 連続性（シームレスな切替）を重視
        ZStack {
            // S0: Standard
            if model.stateManager.currentState == .standard {
                StandardPlayerView(
                    stateManager: model.stateManager,
                    size: size,
                    safeArea: safeArea
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
            
            // S1/S2: Lyrics
            if model.stateManager.isLyricsState {
                LyricsScreenView(
                    stateManager: model.stateManager,
                    size: size,
                    safeArea: safeArea
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
            
            // S3/S4: Queue
            if model.stateManager.isQueueState {
                QueueScreenView(
                    stateManager: model.stateManager,
                    size: size,
                    safeArea: safeArea
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
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
