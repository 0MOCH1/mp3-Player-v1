//
//  AppleMusicNowPlayingView.swift
//  mp3 Player
//

import SwiftUI

struct AppleMusicNowPlayingView: View {
    @Environment(\.playbackController) private var playbackController
    @State private var adapter: NowPlayingAdapter?
    @State private var showOverlay = false
    @State private var expanded = false
    
    var body: some View {
        Color.clear
            .universalOverlay(show: $showOverlay) {
                if let adapter {
                    ExpandableNowPlaying(show: $showOverlay, expanded: $expanded)
                        .environment(adapter)
                }
            }
            .onAppear {
                if let controller = playbackController {
                    adapter = NowPlayingAdapter(controller: controller)
                }
                showOverlay = true
                expanded = true
            }
    }
}
