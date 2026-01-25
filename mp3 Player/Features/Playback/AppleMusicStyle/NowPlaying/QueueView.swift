//
//  QueueView.swift
//  mp3 Player
//
//  Created by GitHub Copilot on 25.01.2026.
//

import SwiftUI

struct QueueView: View {
    @Environment(NowPlayingAdapter.self) var model
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if model.controller.queueItems.isEmpty {
                    ContentUnavailableView {
                        Label("Queue is Empty", systemImage: "list.bullet")
                    } description: {
                        Text("Add songs to your queue to see them here")
                    }
                } else {
                    List {
                        Section {
                            if let currentItem = model.controller.currentItem {
                                QueueItemRow(item: currentItem, isCurrentlyPlaying: true)
                            }
                        } header: {
                            Text("Now Playing")
                        }
                        
                        if !model.controller.queueItems.isEmpty {
                            Section {
                                ForEach(Array(model.controller.queueItems.enumerated()), id: \.element.id) { index, item in
                                    QueueItemRow(item: item, isCurrentlyPlaying: false)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                model.controller.removeFromQueue(at: index)
                                            } label: {
                                                Label("Remove", systemImage: "trash")
                                            }
                                        }
                                }
                                .onMove { fromOffsets, toOffset in
                                    model.controller.moveQueue(fromOffsets: fromOffsets, toOffset: toOffset)
                                }
                            } header: {
                                Text("Up Next")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !model.controller.queueItems.isEmpty {
                        Button(role: .destructive) {
                            model.controller.clearQueue()
                        } label: {
                            Text("Clear")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct QueueItemRow: View {
    let item: PlaybackItem
    let isCurrentlyPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if let artworkUri = item.track.artworkUri {
                ArtworkImageView(artworkUri: artworkUri, cornerRadius: 4, contentMode: .fill)
                    .frame(width: 50, height: 50)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.track.title)
                    .font(.body)
                    .fontWeight(isCurrentlyPlaying ? .semibold : .regular)
                    .foregroundColor(isCurrentlyPlaying ? .accentColor : .primary)
                    .lineLimit(1)
                
                if let artist = item.track.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if isCurrentlyPlaying {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}
