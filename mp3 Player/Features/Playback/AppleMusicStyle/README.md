# Apple Music Style NowPlaying Player

Full-screen Apple Music style player interface for mp3-Player-v1, ported from AppleMusicStylePlayer.

## Overview

This directory contains a complete Apple Music-inspired full-screen player experience that integrates seamlessly with the existing mp3-Player app. It provides a beautiful, animated player interface while keeping the existing mini player intact.

## Architecture

```
AppleMusicStyle/
├── AppleMusicNowPlayingView.swift         # Main entry point
├── NowPlayingAdapter.swift                 # Bridges PlaybackController to views
│
├── NowPlaying/                             # Main player views
│   ├── ExpandableNowPlaying.swift         # Container with gestures
│   ├── RegularNowPlaying.swift            # Full-screen view
│   ├── CompactNowPlaying.swift            # Mini player overlay
│   ├── NowPlayingBackground.swift         # Animated background
│   ├── NowPlayingExpandTracking.swift     # State tracking
│   └── PlayerControls/                    # Playback controls
│       ├── PlayerControls.swift
│       ├── PlayerButtons.swift
│       ├── TimingIndicator.swift
│       └── [...]
│
├── UI/                                     # Reusable UI components
│   ├── Components/
│   │   ├── ElasticSlider.swift           # Interactive slider
│   │   ├── MarqueeText.swift             # Scrolling text
│   │   ├── PlayerButton.swift            # Button component
│   │   └── Background/                   # Animated background
│   │       ├── ColorfulBackground.swift
│   │       ├── MulticolorGradient.swift
│   │       ├── MulticolorGradientShader.metal
│   │       └── [...]
│   │
│   ├── Consts/                           # Constants & styling
│   │   ├── ViewConst.swift
│   │   ├── Palette.swift
│   │   └── AppFont.swift
│   │
│   ├── Extensions/                       # UI helper extensions
│   │   ├── UIColor+Extensions.swift
│   │   ├── UIImage+Extensions.swift
│   │   └── UIScreen+Extensions.swift
│   │
│   ├── Modifiers/                        # SwiftUI modifiers
│   │   ├── Hidden.swift
│   │   ├── MeasureSizeModifier.swift
│   │   └── PressGesture.swift
│   │
│   ├── PanGesture.swift                  # Pan gesture handler
│   ├── UniversalOverlay.swift            # Overlay system
│   ├── DominantColors.swift              # Color extraction
│   └── AnimationExtensions.swift         # Animation helpers
│
└── Helpers/                               # Utility extensions
    ├── ClosedRange+Extensions.swift
    ├── Collection+Extensions.swift
    ├── Time.swift
    └── UIApplication+Extensions.swift
```

## Key Components

### NowPlayingAdapter
Bridges the existing `PlaybackController` with the Apple Music style views. This adapter:
- Exposes playback state as button types (play, pause, forward, backward)
- Provides current time and duration for the progress slider
- Handles color extraction from artwork
- Delegates all playback actions to PlaybackController

### ExpandableNowPlaying
Main container that handles:
- Expanding from mini player to full screen
- Swipe-down gesture to dismiss
- Window stacking effect during transitions
- Coordinating between compact and regular views

### RegularNowPlaying
Full-screen player view with:
- Large artwork display
- Shadow and scaling effects
- Player controls integration
- Smooth animations

### PlayerControls
Complete playback interface:
- Play/Pause, Next, Previous buttons
- Elastic seek slider with time indicators
- Volume slider (UI ready, needs integration)
- Track info with marquee text

### ColorfulBackground
Animated background that:
- Extracts dominant colors from artwork
- Creates smooth color gradients
- Animates between different artwork colors
- Uses Metal shader for performance

## Integration Points

### With PlaybackController
```swift
// Adapter maps PlaybackController to views
adapter.onPlayPause()  → controller.togglePlayPause()
adapter.onForward()    → controller.next()
adapter.onBackward()   → controller.previous()
adapter.seek(to: time) → controller.seek(to: time)
```

### With ContentView
```swift
// Replaces the basic NowPlayingView
.sheet(isPresented: $showsNowPlaying) {
    AppleMusicNowPlayingView()
}
```

### With App Entry
```swift
// Wraps app with overlay system
OverlayableRootView {
    ContentView()
}
```

## Features

✅ **Smooth Animations**
- Expand/collapse with spring animations
- Window stacking effect
- Button press animations
- Color transitions

✅ **Interactive Elements**
- Elastic seek slider with haptic feedback
- Swipe-down gesture to dismiss
- Tap mini player to expand
- Drag slider to seek

✅ **Visual Effects**
- Dominant color extraction from artwork
- Animated gradient background
- Artwork shadow and scaling
- Marquee text for long titles

✅ **Playback Integration**
- Real-time progress updates
- Seek functionality
- State synchronization
- Artwork loading

## Customization

### Colors
Edit `UI/Consts/Palette.swift`:
```swift
static let brand: UIColor = .systemPink  // Change accent color
```

### Animations
Edit `UI/AnimationExtensions.swift`:
```swift
static var playerExpandAnimationDuration: Double {
    0.35  // Adjust timing
}
```

### Layout
Edit `UI/Consts/ViewConst.swift`:
```swift
static let compactNowPlayingHeight: CGFloat = 56  // Mini player height
static let playerCardPaddings: CGFloat = 32       // Padding
```

## Dependencies

- **SwiftUI**: Primary UI framework
- **Observation**: For @Observable classes
- **UIKit**: For color manipulation and effects
- **Metal**: For gradient shader (MulticolorGradientShader.metal)

## Testing

1. **Basic Playback**: Play a track, verify mini player appears
2. **Expand**: Tap mini player, verify smooth expansion
3. **Controls**: Test play/pause, next, previous
4. **Seek**: Drag progress slider, verify seek works
5. **Dismiss**: Swipe down, verify dismissal
6. **Colors**: Play tracks with different artwork, verify color changes

## Known Limitations

- Volume slider UI ready but not connected
- Footer buttons (lyrics, AirPlay, queue) are placeholders
- Requires iOS 17.0+ for Observation framework

## Future Enhancements

- [ ] Connect volume slider to audio control
- [ ] Implement lyrics view
- [ ] Add AirPlay menu
- [ ] Add queue view
- [ ] Add haptic feedback customization
- [ ] Support for landscape orientation

## Credits

Ported from [AppleMusicStylePlayer](https://github.com/vorobyovVV/AppleMusicStylePlayer) by Alexey Vorobyov.
Adapted for mp3-Player-v1 by maintaining integration with existing PlaybackController.
