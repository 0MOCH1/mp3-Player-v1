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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader {
            let size = $0.size
            let safeArea = $0.safeAreaInsets
            let isDragging = offsetY > 0

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
            .clipShape(RoundedRectangle(cornerRadius: isDragging ? 20 : 0))
            .offset(y: offsetY)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let translation = max(value.translation.height, 0)
                        offsetY = translation
                    }
                    .onEnded { value in
                        let translation = max(value.translation.height, 0)
                        let velocity = value.velocity.height / 5
                        
                        // Changed threshold from 0.3 to 0.5 (half the screen)
                        if (translation + velocity) > (size.height * 0.5) {
                            // Dismiss - call immediately without animation delay
                            onDismiss()
                        } else {
                            // Snap back
                            withAnimation(.spring()) {
                                offsetY = 0
                            }
                        }
                    }
            )
            .ignoresSafeArea()
        }
        .background(Color.clear) // Transparent background
        .onAppear {
            model.onAppear()
        }
    }
}

// Simplified version without matched geometry and compact/expand transitions
private struct RegularNowPlayingSimple: View {
    @Environment(NowPlayingAdapter.self) var model
    var size: CGSize
    var safeArea: EdgeInsets

    var body: some View {
        VStack(spacing: 12) {
            grip
                .blendMode(.overlay)

            artwork
                .frame(height: size.width - 50)
                .padding(.vertical, size.height < 700 ? 10 : 30)
                .padding(.horizontal, 25)

            PlayerControls()
        }
        .padding(.top, safeArea.top)
        .padding(.bottom, safeArea.bottom)
    }
    
    var grip: some View {
        Capsule()
            .fill(.white.secondary)
            .frame(width: 40, height: 5)
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
