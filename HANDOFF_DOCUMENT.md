# NowPlaying Screen Reimplementation - Handoff Document

## Project Context

**Repository:** 0MOCH1/mp3-Player-v1  
**Branch:** copilot/migrate-nowplaying-screen  
**Current Commit:** a7aec97 (Fix build errors: use PlaybackItem properties directly and remove unused variable)

## Mission

Complete reimplementation of the NowPlaying screen according to new specification document to replace the current AppleMusicStyle implementation.

**Specification Document:** [now_playing_spec_v2_reviewed.md](https://github.com/user-attachments/files/24845374/now_playing_spec_v2_reviewed.md)

## Current State

### What Has Been Completed (19 commits)
1. ✅ Basic AppleMusicStyle UI components ported
2. ✅ PlaybackController integration
3. ✅ Lyrics, AirPlay, Queue buttons (basic implementation)
4. ✅ Drag-to-dismiss gesture
5. ✅ Volume/seek sliders connected
6. ✅ Device-specific corner radius detection

### Current Implementation Location
```
mp3 Player/Features/Playback/AppleMusicStyle/
├── AppleMusicNowPlayingView.swift
├── NowPlayingAdapter.swift
├── NowPlaying/
│   ├── ExpandableNowPlayingDirect.swift
│   ├── RegularNowPlaying.swift
│   ├── LyricsView.swift
│   ├── QueueView.swift
│   ├── AirPlayButton.swift
│   └── PlayerControls/
└── UI/
    ├── ElasticSlider.swift
    ├── PlayerButton.swift
    └── ColorfulBackground/
```

### Key Files to Reference
- **PlaybackController:** `/mp3 Player/Controllers/PlaybackController.swift`
- **DisplayMedia model:** Used for track info display
- **PlaybackItem model:** Queue items structure
- **ContentView:** `/mp3 Player/ContentView.swift` (integration point)

## New Specification Requirements

### State System (5 States: S0-S4)

#### S0: Standard (Default)
- Full-size artwork centered
- Title/artist below artwork
- Playback controls (play/pause, skip, seek slider, volume)
- Footer buttons (lyrics, AirPlay, queue)

#### S1: Lyrics Small
- Compact header with artwork thumbnail (48pt) + title/artist
- Lyrics scrollable below
- Can expand to S2 or collapse to S0

#### S2: Lyrics Large
- Same compact header
- Full-screen lyrics
- Can collapse to S1 or S0

#### S3: Queue Small
- Compact header with artwork thumbnail (48pt) + title/artist
- Queue list with "Now Playing" + "Up Next" sections
- Complex scroll behavior (see below)
- Can expand to S4 or collapse to S0

#### S4: Queue Reorder Large
- Compact header
- Full-screen queue in edit mode
- Drag handles visible
- Can collapse to S3 or S0

### Critical Features to Implement

#### 1. Compact Header (States S1-S4)
```
┌─────────────────────────────────┐
│ [48x48 artwork] Title          │
│                 Artist      [×] │ ← 48pt fixed height
└─────────────────────────────────┘
```
- Always visible in S1-S4
- Tappable to collapse to S0
- Close button [×] to dismiss to S0

#### 2. Queue Screen Scroll Control (S3)

**Key Concepts:**
- **Snap A:** "History Gate" position (shows previous tracks)
- **Snap B:** "Main" position (Now Playing at top)
- **Phase M (Main):** Outer ScrollView controls scroll
- **Phase H (History):** Inner ScrollView controls scroll
- **History Gate:** 120pt threshold-based snap logic

**Scroll Behavior:**
```
┌─────────────────────────────────┐
│ Compact Header (48pt)           │ ← Always visible
├─────────────────────────────────┤
│                                 │
│ ↕ Outer ScrollView             │
│   controls in Phase M           │
│                                 │
│   ┌───────────────────────┐    │
│   │ QueueControls         │    │ ← Sticky when at Snap B
│   │ (shuffle/repeat)      │    │
│   ├───────────────────────┤    │
│   │ Now Playing           │    │
│   │ ─────────────────     │    │
│   │ Up Next               │    │
│   │ • Track 1             │    │
│   │ • Track 2   ↕ Inner   │    │
│   │ • Track 3   ScrollView│    │
│   │ ...         in Phase H│    │
│   └───────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```

**Phase M → H Transition:**
1. User scrolls up from Snap B
2. When scroll offset < -120pt:
   - Switch to Phase H
   - Inner ScrollView takes control
   - Shows "History" section above Now Playing
3. Snap to Snap A when released

**Phase H → M Transition:**
1. User scrolls down in Phase H
2. When inner ScrollView reaches bottom:
   - Switch to Phase M
   - Outer ScrollView takes control
3. Snap to Snap B

**History Gate Logic:**
```swift
if outerScrollOffset < -120 {
    // Passed threshold: snap to Snap A
    switchToPhaseH()
} else {
    // Below threshold: snap back to Snap B
    snapToSnapB()
}
```

#### 3. Lyrics Screen Snap (S1 ↔ S2)
- Scroll down: expand to S2
- Scroll up: collapse to S1
- Threshold-based snapping (similar to History Gate)

#### 4. State Transitions

**From S0:**
- Tap Lyrics button → S1
- Tap Queue button → S3

**From S1:**
- Scroll down past threshold → S2
- Tap header or swipe down → S0

**From S2:**
- Scroll up past threshold → S1
- Tap header → S0

**From S3:**
- Tap "Edit" → S4
- Scroll down to History Gate → remains S3 (Phase H)
- Tap header or swipe down → S0

**From S4:**
- Tap "Done" → S3
- Tap header → S0

### UI Design Guidelines

**From Reference Images:**
1. Warm color palette (browns, oranges, amber tones)
2. Colorful animated background (blur + gradient)
3. Apple Music-style controls (same as current)
4. Smooth spring animations (0.6s response, 0.8 damping)
5. Corner radius: device-specific (39-62pt)

## Technical Implementation Guide

### Architecture Pattern

```swift
// StateManager.swift
@Observable
class NowPlayingStateManager {
    enum State {
        case standard           // S0
        case lyricsSmall       // S1
        case lyricsLarge       // S2
        case queueSmall        // S3
        case queueReorderLarge // S4
    }
    
    enum ScrollPhase {
        case main    // Phase M
        case history // Phase H
    }
    
    var currentState: State = .standard
    var scrollPhase: ScrollPhase = .main
    var snapPosition: SnapPosition = .snapB
    
    // Transition logic here
}

enum SnapPosition {
    case snapA  // History Gate position
    case snapB  // Main position
}
```

### Key SwiftUI Patterns

#### Nested ScrollView Control
```swift
ScrollView {  // Outer
    VStack {
        CompactHeader()
            .frame(height: 48)
        
        if scrollPhase == .main {
            // Outer scroll active
            QueueContent()
        } else {
            // Phase H: Inner scroll active
            ScrollView {  // Inner
                VStack {
                    HistorySection()
                    QueueContent()
                }
            }
        }
    }
}
.simultaneousGesture(/* scroll detection */)
```

#### Snap Animation
```swift
.onChange(of: scrollOffset) { old, new in
    if abs(new - targetOffset) < threshold {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            scrollToTarget()
        }
    }
}
```

#### Sticky Header (QueueControls)
```swift
LazyVStack(pinnedViews: [.sectionHeaders]) {
    Section {
        // Queue items
    } header: {
        QueueControls()
            .background(.ultraThinMaterial)
    }
}
```

### Critical Measurements

- **Compact Header Height:** 48pt
- **History Gate Threshold:** 120pt
- **Snap Animation:** spring(response: 0.4-0.6, damping: 0.8)
- **Corner Radius:** UIScreen.main.displayCornerRadius ?? 39pt

## Integration Points

### PlaybackController Interface
```swift
// Available properties
controller.state: PlaybackState (.playing, .paused, etc.)
controller.currentItem: PlaybackItem?
controller.queueItems: [PlaybackItem]
controller.currentTime: TimeInterval
controller.duration: TimeInterval
controller.currentLyrics: String?

// Available methods
controller.play()
controller.pause()
controller.skipToNext()
controller.skipToPrevious()
controller.seek(to: TimeInterval)
controller.setVolume(Float)
controller.removeFromQueue(at: Int)
controller.moveQueueItem(from: Int, to: Int)
```

### ContentView Integration
```swift
// Current presentation method
.fullScreenCover(isPresented: $showNowPlaying) {
    AppleMusicNowPlayingView(model: nowPlayingModel)
        .presentationBackground(.clear)
}
```

## Implementation Strategy

### Phase 1: Core State System (3-4 hours)
1. Create `NowPlayingStateManager.swift`
2. Implement S0-S4 state enum
3. Basic state transition logic
4. CompactHeader component (48pt)

### Phase 2: Queue Screen (4-6 hours)
1. Implement Snap A/B positions
2. Nested ScrollView with Phase M/H
3. History Gate threshold logic
4. QueueControls sticky header
5. Scroll ownership transfer

### Phase 3: Lyrics Screen (2-3 hours)
1. S1/S2 snap logic
2. Scroll threshold detection
3. Smooth expand/collapse animation

### Phase 4: S4 Reorder Mode (2-3 hours)
1. Edit mode UI
2. Drag handles
3. onMove implementation

### Phase 5: Polish (2-3 hours)
1. All state transitions smooth
2. Animation tuning
3. Edge case handling
4. Testing

**Total Estimated Time:** 13-19 hours

## Testing Checklist

- [ ] S0 → S1 → S2 → S1 → S0 transition flow
- [ ] S0 → S3 → S4 → S3 → S0 transition flow
- [ ] Queue Phase M ↔ H switching
- [ ] History Gate snap behavior
- [ ] Snap A/B positioning
- [ ] QueueControls sticky behavior
- [ ] Compact header tap to collapse
- [ ] Lyrics scroll snap thresholds
- [ ] All animations smooth (60fps)
- [ ] PlaybackController integration functional
- [ ] No memory leaks
- [ ] Build succeeds with no warnings

## Known Issues & Considerations

1. **Current Implementation:** Uses fullScreenCover presentation - keep this or switch to ZStack overlay?
2. **Drag-to-dismiss:** Current implementation may conflict with scroll gestures - needs careful handling
3. **Corner Radius:** Already implemented device detection - reuse `UIScreen+DisplayCornerRadius.swift`
4. **Volume Slider:** Already connected to PlaybackController - preserve this
5. **Color Scheme:** Current brown/amber theme matches reference images - preserve

## Files to Modify/Create

### Create New:
- [ ] `NowPlayingStateManager.swift`
- [ ] `CompactHeader.swift`
- [ ] `QueueScreenView.swift` (with nested scroll)
- [ ] `LyricsScreenView.swift` (with snap)
- [ ] `StandardPlayerView.swift` (S0 state)
- [ ] `QueueControlsView.swift` (sticky header)

### Modify:
- [ ] `AppleMusicNowPlayingView.swift` (main coordinator)
- [ ] `NowPlayingAdapter.swift` (add state management)
- [ ] `ContentView.swift` (presentation logic)

### Remove/Archive:
- [ ] Old `ExpandableNowPlayingDirect.swift` (after migration)
- [ ] Old `LyricsView.swift` (replace with new)
- [ ] Old `QueueView.swift` (replace with new)

## Communication with Previous Work

**Previous commits contain:**
- Working PlaybackController integration ✅
- Device corner radius detection ✅
- Volume/seek slider connections ✅
- Basic UI components (ElasticSlider, PlayerButton) ✅

**DO NOT discard:**
- `UIScreen+DisplayCornerRadius.swift`
- `ElasticSlider.swift`
- `PlayerButton.swift`
- `NowPlayingAdapter.swift` (expand, don't replace)
- `ColorfulBackground/` shader code

## Questions to Resolve

1. Should History section in queue actually show previously played tracks, or is it just for scroll behavior?
2. Exact pixel measurements for Snap A position?
3. Should S4 (reorder mode) dim the background?
4. Haptic feedback on state transitions?
5. Accessibility considerations for complex scroll?

## Success Criteria

✅ All 5 states (S0-S4) implemented and functional  
✅ Queue Phase M/H switching works smoothly  
✅ History Gate snap logic functions correctly  
✅ Lyrics S1/S2 snap works  
✅ Compact header present in S1-S4  
✅ All state transitions animated  
✅ PlaybackController integration preserved  
✅ UI matches reference images  
✅ No build errors or warnings  
✅ Performance: 60fps scrolling

## Contact & Resources

- **Spec Document:** https://github.com/user-attachments/files/24845374/now_playing_spec_v2_reviewed.md
- **Reference Images:** See PR comments (6 images showing S0-S4 states)
- **Previous Agent:** Completed basic implementation, stopped at scope assessment
- **Repository Owner:** @0MOCH1

---

**Next Steps for Implementing Agent:**
1. Read specification document thoroughly
2. Review reference images to understand visual requirements
3. Start with Phase 1 (Core State System)
4. Commit incrementally after each phase
5. Test each state transition before moving forward

Good luck! 🚀
