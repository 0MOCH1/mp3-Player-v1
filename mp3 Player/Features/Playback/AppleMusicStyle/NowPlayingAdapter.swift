//
//  NowPlayingAdapter.swift
//  mp3 Player
//

import SwiftUI
import Observation
import Combine

// MARK: - State Model

/// FullPlayer内のモード（NowPlaying / Lyrics / Queue）
enum PlayerMode: Equatable {
    case nowPlaying
    case lyrics
    case queue
}

/// Controlsの表示状態
enum ControlsVisibility: Equatable {
    case shown
    case hidden
}

/// QueuePanel内のサブ状態
enum QueueSubstate: Equatable {
    case browsing
    case reordering
}

// MARK: - NowPlayingAdapter

@MainActor
@Observable
class NowPlayingAdapter {
    let controller: PlaybackController
    var colors: [ColorFrequency] = []
    
    // Mirror controller properties for observation
    private(set) var state: PlaybackState = .stopped
    private(set) var currentItem: PlaybackItem?
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var currentLyrics: String?
    private(set) var queueItems: [PlaybackItem] = []
    private(set) var isShuffleEnabled: Bool = false
    private(set) var repeatMode: RepeatMode = .off
    
    // State Model properties
    var playerMode: PlayerMode = .nowPlaying
    var controlsVisibility: ControlsVisibility = .shown
    var queueSubstate: QueueSubstate = .browsing
    
    private var cancellables = Set<AnyCancellable>()
    
    init(controller: PlaybackController) {
        self.controller = controller
        
        // Subscribe to controller changes
        controller.$state
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)
        
        controller.$currentItem
            .sink { [weak self] newItem in
                self?.currentItem = newItem
                self?.updateColors()
            }
            .store(in: &cancellables)
        
        controller.$currentTime
            .sink { [weak self] newTime in
                self?.currentTime = newTime
            }
            .store(in: &cancellables)
        
        controller.$duration
            .sink { [weak self] newDuration in
                self?.duration = newDuration
            }
            .store(in: &cancellables)
        
        controller.$currentLyrics
            .sink { [weak self] newLyrics in
                self?.currentLyrics = newLyrics
            }
            .store(in: &cancellables)
        
        controller.$queueItems
            .sink { [weak self] newQueue in
                self?.queueItems = newQueue
            }
            .store(in: &cancellables)
        
        controller.$isShuffleEnabled
            .sink { [weak self] newValue in
                self?.isShuffleEnabled = newValue
            }
            .store(in: &cancellables)
        
        controller.$repeatMode
            .sink { [weak self] newMode in
                self?.repeatMode = newMode
            }
            .store(in: &cancellables)
        
        // Initialize with current values
        self.state = controller.state
        self.currentItem = controller.currentItem
        self.currentTime = controller.currentTime
        self.duration = controller.duration
        self.currentLyrics = controller.currentLyrics
        self.queueItems = controller.queueItems
        self.isShuffleEnabled = controller.isShuffleEnabled
        self.repeatMode = controller.repeatMode
    }
    
    var display: DisplayMedia {
        if let item = currentItem {
            return DisplayMedia(
                artworkUri: item.artworkUri,
                title: item.title,
                subtitle: item.artist
            )
        } else {
            return DisplayMedia.placeholder
        }
    }
    
    var title: String {
        display.title
    }
    
    var subtitle: String? {
        display.subtitle
    }
    
    var playPauseButton: ButtonType {
        switch state {
        case .playing: .pause
        case .paused, .stopped, .buffering: .play
        }
    }
    
    var backwardButton: ButtonType { .backward }
    var forwardButton: ButtonType { .forward }
    
    func onAppear() {
        updateColors()
    }
    
    func onPlayPause() {
        controller.togglePlayPause()
    }
    
    func onForward() {
        controller.next()
    }
    
    func onBackward() {
        controller.previous()
    }
    
    func seek(to time: Double) {
        controller.seek(to: time)
    }
    
    // MARK: - Mode Toggle Functions
    
    /// LyricsButtonでNowPlaying ↔ Lyricsをトグル
    func toggleLyrics() {
        if playerMode == .lyrics {
            playerMode = .nowPlaying
            controlsVisibility = .shown
        } else {
            playerMode = .lyrics
            queueSubstate = .browsing
        }
    }
    
    /// QueueButtonでNowPlaying ↔ Queueをトグル
    func toggleQueue() {
        if playerMode == .queue {
            playerMode = .nowPlaying
            controlsVisibility = .shown
            queueSubstate = .browsing
        } else {
            playerMode = .queue
            controlsVisibility = .shown
            queueSubstate = .browsing
        }
    }
    
    /// ControlsVisibilityを切り替え（Lyricsモード用）
    func setControlsVisibility(_ visibility: ControlsVisibility) {
        // Queueモードでは常にShown（Reordering時のみHidden）
        if playerMode == .queue && queueSubstate != .reordering {
            controlsVisibility = .shown
        } else {
            controlsVisibility = visibility
        }
    }
    
    /// Reordering開始
    func startReordering() {
        guard playerMode == .queue else { return }
        queueSubstate = .reordering
        controlsVisibility = .hidden
    }
    
    /// Reordering終了
    func endReordering() {
        queueSubstate = .browsing
        controlsVisibility = .shown
    }
    
    /// NowPlayingモードに戻る
    func resetToNowPlaying() {
        playerMode = .nowPlaying
        controlsVisibility = .shown
        queueSubstate = .browsing
    }
    
    // MARK: - Queue Controls
    
    /// シャッフルをトグル
    func toggleShuffle() {
        controller.isShuffleEnabled.toggle()
    }
    
    /// リピートモードをサイクル
    func cycleRepeat() {
        switch controller.repeatMode {
        case .off:
            controller.repeatMode = .all
        case .all:
            controller.repeatMode = .one
        case .one:
            controller.repeatMode = .off
        }
    }
    
    /// キューからアイテムを削除
    func removeFromQueue(at index: Int) {
        controller.removeFromQueue(at: index)
    }
    
    /// キューの並び替え
    func moveQueue(fromOffsets: IndexSet, toOffset: Int) {
        controller.moveQueue(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    
    func updateColors() {
        guard let artworkUri = currentItem?.artworkUri,
              let url = URL(string: artworkUri) else {
            colors = []
            return
        }
        
        Task { @MainActor in
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                self.colors = (image.dominantColorFrequencies(with: .high) ?? [])
            }
        }
    }
}

struct DisplayMedia {
    let artworkUri: String?
    let title: String
    let subtitle: String?
    
    static var placeholder: Self {
        DisplayMedia(
            artworkUri: nil,
            title: "---",
            subtitle: "---"
        )
    }
}
