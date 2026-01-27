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
            let _ = dragProgress * deviceCornerRadius

            ZStack(alignment: .top) {
                NowPlayingBackground(
                    colors: model.colors.map { Color($0.color) },
                    expanded: true,
                    isFullExpanded: true
                )
                
                RegularNowPlayingSimple(
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

// Simplified version without matched geometry and compact/expand transitions
private struct RegularNowPlayingSimple: View {
    @Environment(NowPlayingAdapter.self) var model
    var size: CGSize
    var safeArea: EdgeInsets

    var body: some View {
        ZStack(alignment: .top) {
            // Top-anchored elements (Grip and Artwork)
            VStack(spacing: 0) {
                grip
                    .blendMode(.overlay)
                    .padding(.top, calculateGripTopPadding())

                artwork
                    .frame(height: size.width - 50)
                    .padding(.vertical, size.height < 700 ? 10 : 30)
                    .padding(.horizontal, 25)
            }
            .padding(.top, safeArea.top)
            .frame(maxHeight: .infinity, alignment: .top)
            
            // Bottom-anchored elements (Title to Footer)
            PlayerControls()
                .padding(.bottom, safeArea.bottom)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
    
    var grip: some View {
        Capsule()
            .fill(.white.secondary)
            // Doubled width from 40 to 80
            .frame(width: 80, height: 5)
    }
    
    func calculateGripTopPadding() -> CGFloat {
        // Dynamic Island bottom is at safeArea.top
        // Artwork top (without current padding) would be at some position
        // Current VStack has spacing: 12
        // We want grip centered between Dynamic Island bottom and artwork top
        // Approximate calculation: place grip in the middle of available space
        // Since we're in VStack with safeArea.top padding and spacing: 12
        // The grip should be positioned to create equal spacing
        // Default positioning with no extra padding creates ~12pt below DI
        // and ~12pt above artwork due to VStack spacing
        // To make them equal, we need to adjust based on visible gap
        // Simplified: add slight offset to better center visually
        return 8 // Additional padding to fine-tune position
    }

    var artwork: some View {
        GeometryReader {
            let size = $0.size
            // Show smaller when paused, full size when playing
            let isPlaying = model.state == .playing
            ArtworkImageView(artworkUri: model.display.artworkUri, cornerRadius: 10, contentMode: .fill)
                .padding(isPlaying ? 0 : 48)
                .shadow(
                    color: Color(.sRGBLinear, white: 0, opacity: isPlaying ? 0.33 : 0.13),
                    radius: isPlaying ? 8 : 3,
                    y: isPlaying ? 10 : 3
                )
                .frame(width: size.width, height: size.height)
                .animation(.smooth, value: model.state)
        }
    }
}
