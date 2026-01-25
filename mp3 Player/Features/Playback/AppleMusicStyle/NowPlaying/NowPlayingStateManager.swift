//
//  NowPlayingStateManager.swift
//  mp3 Player
//

import SwiftUI
import Observation

/// Manages the state of the NowPlaying screen
/// States: S0 (Standard), S1 (Lyrics Small), S2 (Lyrics Large), S3 (Queue Small), S4 (Queue Reorder)
@MainActor
@Observable
class NowPlayingStateManager {
    
    /// The 5 possible states of the NowPlaying screen
    enum State: Equatable {
        case standard           // S0 - Full artwork with controls
        case lyricsSmall       // S1 - Compact header + small lyrics
        case lyricsLarge       // S2 - Compact header + full lyrics
        case queueSmall        // S3 - Compact header + queue list
        case queueReorderLarge // S4 - Compact header + queue in edit mode
    }
    
    /// Scroll phase for queue screen (S3)
    enum ScrollPhase: Equatable {
        case main    // Phase M - Outer ScrollView controls
        case history // Phase H - Inner ScrollView controls (History visible)
    }
    
    /// Snap positions for queue screen
    enum SnapPosition: Equatable {
        case snapA  // History Gate position (shows history)
        case snapB  // Main position (Now Playing at top)
    }
    
    // MARK: - State Properties
    
    /// Current state of the NowPlaying screen
    var currentState: State = .standard
    
    /// Scroll phase for queue screen (only relevant in S3)
    var scrollPhase: ScrollPhase = .main
    
    /// Current snap position for queue screen
    var snapPosition: SnapPosition = .snapB
    
    /// Outer scroll offset for queue screen
    var outerScrollOffset: CGFloat = 0
    
    /// Inner scroll offset for history section
    var innerScrollOffset: CGFloat = 0
    
    // MARK: - Constants
    
    /// Threshold for History Gate (120pt)
    static let historyGateThreshold: CGFloat = 120
    
    /// Threshold for lyrics screen snap transitions (S1 ↔ S2)
    static let lyricsSnapThreshold: CGFloat = 100
    
    /// Height of compact header
    static let compactHeaderHeight: CGFloat = 48
    
    /// Artwork size in compact header
    static let compactArtworkSize: CGFloat = 48
    
    /// Animation for state transitions
    static let transitionAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.8)
    
    // MARK: - Computed Properties
    
    /// Whether compact header should be shown (S1-S4)
    var showsCompactHeader: Bool {
        switch currentState {
        case .standard:
            return false
        case .lyricsSmall, .lyricsLarge, .queueSmall, .queueReorderLarge:
            return true
        }
    }
    
    /// Whether we're in a lyrics state
    var isLyricsState: Bool {
        currentState == .lyricsSmall || currentState == .lyricsLarge
    }
    
    /// Whether we're in a queue state
    var isQueueState: Bool {
        currentState == .queueSmall || currentState == .queueReorderLarge
    }
    
    /// Whether queue is in edit/reorder mode
    var isQueueEditMode: Bool {
        currentState == .queueReorderLarge
    }
    
    // MARK: - State Transition Methods
    
    /// Transition to Standard state (S0)
    func goToStandard() {
        withAnimation(Self.transitionAnimation) {
            currentState = .standard
            scrollPhase = .main
            snapPosition = .snapB
        }
    }
    
    /// Transition to Lyrics Small state (S1)
    func goToLyricsSmall() {
        withAnimation(Self.transitionAnimation) {
            currentState = .lyricsSmall
        }
    }
    
    /// Transition to Lyrics Large state (S2)
    func goToLyricsLarge() {
        withAnimation(Self.transitionAnimation) {
            currentState = .lyricsLarge
        }
    }
    
    /// Transition to Queue Small state (S3)
    func goToQueueSmall() {
        withAnimation(Self.transitionAnimation) {
            currentState = .queueSmall
            scrollPhase = .main
            snapPosition = .snapB
        }
    }
    
    /// Transition to Queue Reorder state (S4)
    func goToQueueReorder() {
        withAnimation(Self.transitionAnimation) {
            currentState = .queueReorderLarge
        }
    }
    
    /// Toggle lyrics button - from S0 goes to S1, from S1/S2 goes to S0
    func toggleLyrics() {
        if isLyricsState {
            goToStandard()
        } else {
            goToLyricsSmall()
        }
    }
    
    /// Toggle queue button - from S0 goes to S3, from S3/S4 goes to S0
    func toggleQueue() {
        if isQueueState {
            goToStandard()
        } else {
            goToQueueSmall()
        }
    }
    
    /// Toggle edit mode in queue - between S3 and S4
    func toggleQueueEditMode() {
        if currentState == .queueSmall {
            goToQueueReorder()
        } else if currentState == .queueReorderLarge {
            goToQueueSmall()
        }
    }
    
    // MARK: - Scroll Handling
    
    /// Handle outer scroll offset change for queue History Gate logic
    func handleOuterScrollChange(_ offset: CGFloat) {
        outerScrollOffset = offset
        
        // Check if we've passed the History Gate threshold
        if offset < -Self.historyGateThreshold && scrollPhase == .main {
            // Switch to Phase H (History)
            withAnimation(Self.transitionAnimation) {
                scrollPhase = .history
                snapPosition = .snapA
            }
        }
    }
    
    /// Handle scroll end for snapping behavior
    func handleScrollEnd() {
        if scrollPhase == .main {
            // In Phase M, snap based on threshold
            if outerScrollOffset < -Self.historyGateThreshold {
                // Past threshold: snap to Snap A
                withAnimation(Self.transitionAnimation) {
                    scrollPhase = .history
                    snapPosition = .snapA
                }
            } else {
                // Below threshold: snap back to Snap B
                withAnimation(Self.transitionAnimation) {
                    snapPosition = .snapB
                    outerScrollOffset = 0
                }
            }
        }
    }
    
    /// Switch from Phase H back to Phase M
    func switchToPhaseMain() {
        withAnimation(Self.transitionAnimation) {
            scrollPhase = .main
            snapPosition = .snapB
            outerScrollOffset = 0
        }
    }
    
    /// Handle lyrics scroll for S1 ↔ S2 snap transitions
    func handleLyricsScrollChange(_ offset: CGFloat) {
        let threshold = Self.lyricsSnapThreshold
        if currentState == .lyricsSmall && offset > threshold {
            goToLyricsLarge()
        } else if currentState == .lyricsLarge && offset < -threshold {
            goToLyricsSmall()
        }
    }
}
