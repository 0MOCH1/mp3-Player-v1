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
    @Namespace private var animationNamespace

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
                
                RegularNowPlaying(
                    expanded: $expanded,
                    size: size,
                    safeArea: safeArea,
                    animationNamespace: animationNamespace
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
                        
                        if (translation + velocity) > (size.height * 0.3) {
                            // Dismiss
                            withAnimation(.easeOut(duration: 0.25)) {
                                offsetY = size.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onDismiss()
                            }
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
        .onAppear {
            model.onAppear()
        }
    }
}
