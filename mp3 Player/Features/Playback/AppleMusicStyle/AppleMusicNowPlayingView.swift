//
//  AppleMusicNowPlayingView.swift
//  mp3 Player
//

import SwiftUI

struct AppleMusicNowPlayingView: View {
    @Environment(\.playbackController) private var playbackController
    @Environment(\.dismiss) private var dismiss
    @State private var adapter: NowPlayingAdapter?
    @State private var expanded = true
    
    var body: some View {
        ZStack {
            if let adapter {
                ExpandableNowPlayingDirect(
                    expanded: $expanded,
                    onDismiss: { dismiss() }
                )
                .environment(adapter)
            }
        }
        .onAppear {
            if let controller = playbackController {
                adapter = NowPlayingAdapter(controller: controller)
            }
        }
    }
}
