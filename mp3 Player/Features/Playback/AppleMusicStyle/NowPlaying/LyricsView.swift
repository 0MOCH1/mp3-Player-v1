//
//  LyricsView.swift
//  mp3 Player
//
//  Created by GitHub Copilot on 25.01.2026.
//

import SwiftUI

struct LyricsView: View {
    @Environment(NowPlayingAdapter.self) var model
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if let lyrics = model.currentLyrics, !lyrics.isEmpty {
                    ScrollView {
                        Text(lyrics)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Lyrics Available", systemImage: "text.quote")
                    } description: {
                        Text("Lyrics for this track are not available")
                    }
                }
            }
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
