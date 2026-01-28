import SwiftUI

// MARK: - Scroll Position PreferenceKey

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Scroll Position Detection View
// Place this at the top of a ScrollView to detect scroll position

struct ScrollPositionDetector: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scrollCoordinate")).minY
                )
        }
        .frame(height: 0)
    }
}

// MARK: - Usage Example
/*
 ScrollView {
     VStack {
         ScrollPositionDetector() // Place at top
         
         // Your content here
     }
 }
 .coordinateSpace(name: "scrollCoordinate")
 .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
     withAnimation {
         showHeader = value < -threshold
     }
 }
 */

