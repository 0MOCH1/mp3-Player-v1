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
            // Always show at full size when NowPlaying screen is open
            ArtworkImageView(artworkUri: model.display.artworkUri, cornerRadius: 10, contentMode: .fill)
                .shadow(
                    color: Color(.sRGBLinear, white: 0, opacity: 0.33),
                    radius: 8,
                    y: 10
                )
                .frame(width: size.width, height: size.height)
        }
    }
}
