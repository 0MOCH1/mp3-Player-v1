//
//  ContentView.swift
//  mp3 Player
//
//  Created by Minato on 2026/01/19.
//

import SwiftUI

struct ContentView: View {
    @State private var showsSettings = false
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.playbackController) private var playbackController
    @State private var didStartScan = false
    @State private var showsNowPlaying = false

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView(showsSettings: $showsSettings)
            }

            Tab("Library", systemImage: "music.note.list") {
                LibraryView(showsSettings: $showsSettings)
            }

            Tab(role: .search) {
                SearchView(showsSettings: $showsSettings)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if let controller = playbackController {
                MiniPlayerAccessory(controller: controller) {
                    showsNowPlaying = true
                }
                .tint(.black)
            }
        }
        .tint(AppTheme.tint)
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showsNowPlaying) {
            AppleMusicNowPlayingView()
        }
        .task {
            guard !didStartScan else { return }
            didStartScan = true
            guard let appDatabase else { return }
            await StartupScanCoordinator.shared.scanIfNeeded(appDatabase: appDatabase)
        }
    }
}

private struct MiniPlayerAccessory: View {
    @ObservedObject var controller: PlaybackController
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    let onActivate: () -> Void

    private var hasItem: Bool {
        controller.currentItem != nil
    }

    var body: some View {
        Group {
            if placement == .inline {
                inlineContent
            } else {
                fullContent
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard hasItem else { return }
            onActivate()
        }
    }

    private var inlineContent: some View {
        HStack(spacing: 8) {
            if let artworkUri = controller.currentItem?.artworkUri {
                ArtworkImageView(artworkUri: artworkUri, cornerRadius: 6, contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(controller.currentItem?.title ?? "Not Playing")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                if let artist = controller.currentItem?.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.state == .playing ? "pause.fill" : "play.fill")
                    .font(.body.weight(.bold))
                    .contentTransition(.symbolEffect(.replace.offUp))
            }
            .disabled(!hasItem)
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 16)
    }

    private var fullContent: some View {
        HStack(spacing: 8) {
            if let artworkUri = controller.currentItem?.artworkUri {
                ArtworkImageView(artworkUri: artworkUri, cornerRadius: 6, contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(controller.currentItem?.title ?? "Not Playing")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                if let artist = controller.currentItem?.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.state == .playing ? "pause.fill" : "play.fill")
                    .font(.body.weight(.bold))
                    .contentTransition(.symbolEffect(.replace.offUp))
            }
            .disabled(!hasItem)

            Button {
                controller.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.body.weight(.bold))
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .disabled(!hasItem)
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    ContentView()
}
