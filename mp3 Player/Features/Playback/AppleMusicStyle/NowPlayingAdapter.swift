//
//  NowPlayingAdapter.swift
//  mp3 Player
//

import SwiftUI
import Observation

@MainActor
@Observable
class NowPlayingAdapter {
    let controller: PlaybackController
    var colors: [ColorFrequency] = []
    
    init(controller: PlaybackController) {
        self.controller = controller
    }
    
    var display: DisplayMedia {
        if let item = controller.currentItem {
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
        switch controller.state {
        case .playing: .pause
        case .paused, .stopped: .play
        }
    }
    
    var backwardButton: ButtonType { .backward }
    var forwardButton: ButtonType { .forward }
    
    var currentTime: Double {
        controller.currentTime
    }
    
    var duration: Double {
        controller.duration
    }
    
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
        Task {
            await controller.seek(to: time)
        }
    }
    
    func updateColors() {
        guard let artworkUri = controller.currentItem?.artworkUri,
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
