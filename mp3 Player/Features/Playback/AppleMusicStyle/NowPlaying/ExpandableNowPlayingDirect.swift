//
//  ExpandableNowPlayingDirect.swift
//  mp3 Player
//

import SwiftUI

struct ExpandableNowPlayingDirect: View {
    @Binding var expanded: Bool
    let onDismiss: () -> Void
    @Environment(NowPlayingAdapter.self) var model
    @State private var offsetY: CGFloat = 0.0
    @State private var expandProgress: CGFloat = 1.0
    @State private var deviceCornerRadius: CGFloat = 39.0
    @State private var currentCornerRadius: CGFloat = 0.0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader {
            let size = $0.size
            let safeArea = $0.safeAreaInsets
            
            // Calculate progressive corner radius based on drag amount
            // Reaches full device corner radius at 20pt of drag
            let dragProgress = min(offsetY / 20.0, 1.0)
            let targetCornerRadius = dragProgress * deviceCornerRadius

            ZStack(alignment: .top) {
                NowPlayingBackground(
                    colors: model.colors.map { Color($0.color) },
                    expanded: true,
                    isFullExpanded: true
                )
                
                NowPlayingContentView(
                    size: size,
                    safeArea: safeArea
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
            .offset(y: offsetY)
            .gesture(
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
            )
            .ignoresSafeArea()
        }
        .background(Color.clear) // Transparent background
        .onAppear {
            model.onAppear()
            // Get the device's actual corner radius
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let screen = windowScene.screen as UIScreen? {
                deviceCornerRadius = screen.displayCornerRadius
            }
        }
    }
}
