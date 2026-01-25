//
//  NowPlayingStateManager.swift
//  mp3 Player
//
//  State manager for the NowPlaying screen following PLAYING_SCREEN_SPEC.md
//

import SwiftUI
import Observation

/// NowPlaying screen states (S0-S4)
enum NowPlayingState: Equatable {
    /// S0: Standard state - Full artwork with controls
    case standard
    /// S1: Lyrics small - Compact header + lyrics + controls visible
    case lyricsSmall
    /// S2: Lyrics large - Compact header + full lyrics + controls hidden
    case lyricsLarge
    /// S3: Queue small - Compact header + queue list + controls visible
    case queueSmall
    /// S4: Queue reorder large - Full queue reorder mode + controls hidden
    case queueReorderLarge
}

/// Scroll phase for queue screen (S3) - controls scroll ownership
enum QueueScrollPhase: Equatable {
    /// Phase M: Main phase - outer scroll controls, QueueControls may become sticky
    case main
    /// Phase H: History phase - viewing history section
    case history
}

/// Snap positions for queue screen (S3)
enum QueueSnapPosition: Equatable {
    /// Snap A: History gate position - history bottom aligns with viewport bottom
    case snapA
    /// Snap B: Main position - compact track info at top (initial position)
    case snapB
}

@MainActor
@Observable
class NowPlayingStateManager {
    /// Current screen state
    var currentState: NowPlayingState = .standard
    
    /// Queue scroll phase (only relevant in S3)
    var scrollPhase: QueueScrollPhase = .main
    
    /// Queue snap position (only relevant in S3)
    var snapPosition: QueueSnapPosition = .snapB
    
    /// Whether the queue is in edit/reorder mode
    var isQueueEditMode: Bool = false
    
    // MARK: - State Transitions
    
    /// Toggle lyrics view (S0 ↔ S1)
    func toggleLyrics() {
        withAnimation(.smooth(duration: 0.35)) {
            switch currentState {
            case .standard:
                currentState = .lyricsSmall
            case .lyricsSmall, .lyricsLarge:
                currentState = .standard
            case .queueSmall, .queueReorderLarge:
                // Switch from queue to lyrics
                currentState = .lyricsSmall
            }
        }
    }
    
    /// Toggle queue view (S0 ↔ S3)
    func toggleQueue() {
        withAnimation(.smooth(duration: 0.35)) {
            switch currentState {
            case .standard:
                currentState = .queueSmall
                scrollPhase = .main
                snapPosition = .snapB
            case .queueSmall, .queueReorderLarge:
                currentState = .standard
                isQueueEditMode = false
            case .lyricsSmall, .lyricsLarge:
                // Switch from lyrics to queue
                currentState = .queueSmall
                scrollPhase = .main
                snapPosition = .snapB
            }
        }
    }
    
    /// Return to standard state (S0) - triggered by tapping compact header
    func returnToStandard() {
        withAnimation(.smooth(duration: 0.35)) {
            currentState = .standard
            isQueueEditMode = false
        }
    }
    
    /// Expand lyrics to large (S1 → S2)
    func expandLyrics() {
        guard currentState == .lyricsSmall else { return }
        withAnimation(.smooth(duration: 0.35)) {
            currentState = .lyricsLarge
        }
    }
    
    /// Collapse lyrics to small (S2 → S1)
    func collapseLyrics() {
        guard currentState == .lyricsLarge else { return }
        withAnimation(.smooth(duration: 0.35)) {
            currentState = .lyricsSmall
        }
    }
    
    /// Enter queue reorder mode (S3 → S4)
    func enterQueueReorderMode() {
        guard currentState == .queueSmall else { return }
        withAnimation(.smooth(duration: 0.35)) {
            currentState = .queueReorderLarge
            isQueueEditMode = true
        }
    }
    
    /// Exit queue reorder mode (S4 → S3)
    func exitQueueReorderMode() {
        guard currentState == .queueReorderLarge else { return }
        withAnimation(.smooth(duration: 0.35)) {
            currentState = .queueSmall
            isQueueEditMode = false
        }
    }
    
    // MARK: - Scroll Phase Control
    
    /// Update scroll phase based on scroll position
    func updateScrollPhase(to phase: QueueScrollPhase) {
        guard currentState == .queueSmall else { return }
        scrollPhase = phase
    }
    
    /// Snap to position A (history gate)
    func snapToA() {
        guard currentState == .queueSmall else { return }
        withAnimation(.smooth(duration: 0.35)) {
            snapPosition = .snapA
        }
    }
    
    /// Snap to position B (main/initial)
    func snapToB() {
        guard currentState == .queueSmall else { return }
        withAnimation(.smooth(duration: 0.35)) {
            snapPosition = .snapB
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether controls should be visible
    var showsControls: Bool {
        switch currentState {
        case .standard, .lyricsSmall, .queueSmall:
            return true
        case .lyricsLarge, .queueReorderLarge:
            return false
        }
    }
    
    /// Whether compact header should be visible
    var showsCompactHeader: Bool {
        switch currentState {
        case .standard:
            return false
        case .lyricsSmall, .lyricsLarge, .queueSmall, .queueReorderLarge:
            return true
        }
    }
    
    /// Whether in lyrics mode (S1 or S2)
    var isLyricsMode: Bool {
        switch currentState {
        case .lyricsSmall, .lyricsLarge:
            return true
        default:
            return false
        }
    }
    
    /// Whether in queue mode (S3 or S4)
    var isQueueMode: Bool {
        switch currentState {
        case .queueSmall, .queueReorderLarge:
            return true
        default:
            return false
        }
    }
}
