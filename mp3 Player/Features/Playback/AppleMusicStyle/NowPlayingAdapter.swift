//
//  NowPlayingAdapter.swift
//  mp3 Player
//

import SwiftUI
import Observation
import Combine

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
        
        // Initialize with current values
        self.state = controller.state
        self.currentItem = controller.currentItem
        self.currentTime = controller.currentTime
        self.duration = controller.duration
        self.currentLyrics = controller.currentLyrics
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
