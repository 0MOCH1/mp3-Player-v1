//
//  QueueScreenView.swift
//  mp3 Player
//

import SwiftUI

/// Queue screen view for states S3 (queue small) and S4 (queue reorder)
/// Features:
/// - Compact header with artwork + title/artist
/// - Queue controls (shuffle, repeat, infinity, autoplay)
/// - History section (visible at Snap A)
/// - Now Playing + Up Next sections
/// - Phase M/H scroll behavior with History Gate
struct QueueScreenView: View {
    @Environment(NowPlayingAdapter.self) var model
    let stateManager: NowPlayingStateManager
    var size: CGSize
    var safeArea: EdgeInsets
    
    @State private var outerScrollOffset: CGFloat = 0
    @State private var showHistory: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Grip indicator
            grip
                .padding(.top, safeArea.top)
            
            // Compact Header
            CompactHeader(stateManager: stateManager)
            
            // Queue Controls (sticky)
            QueueControlsView()
            
            // Queue Content
            queueContent
            
            // Bottom controls
            bottomControls
                .padding(.bottom, safeArea.bottom)
        }
    }
    
    private var grip: some View {
        Capsule()
            .fill(.white.secondary)
            .frame(width: 40, height: 5)
            .padding(.vertical, 8)
    }
    
    private var queueContent: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        // History Section (Phase H / Snap A)
                        if showHistory || stateManager.scrollPhase == .history {
                            historySection
                                .id("history")
                        }
                        
                        // Section header
                        sectionHeader
                            .id("nowPlaying")
                        
                        // Up Next queue items
                        upNextSection
                    }
                    .background(
                        GeometryReader { scrollGeo in
                            Color.clear.preference(
                                key: QueueScrollOffsetKey.self,
                                value: scrollGeo.frame(in: .named("queueScroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "queueScroll")
                .onPreferenceChange(QueueScrollOffsetKey.self) { value in
                    outerScrollOffset = value
                    handleScrollChange(value)
                }
            }
        }
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("履歴")
                    .font(.headline)
                    .foregroundStyle(Color(Palette.playerCard.opaque))
                
                Spacer()
                
                Button("消去") {
                    // Clear history action
                }
                .font(.subheadline)
                .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.7))
            }
            .padding(.horizontal, ViewConst.playerCardPaddings)
            .padding(.vertical, 12)
            
            // History items (mock data for now - would come from PlaybackController)
            ForEach(0..<5, id: \.self) { index in
                QueueItemRowView(
                    item: mockHistoryItem(index: index),
                    isCurrentlyPlaying: false,
                    showsDragHandle: false,
                    onTap: {}
                )
            }
        }
    }
    
    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("再生を続ける")
                .font(.headline)
                .foregroundStyle(Color(Palette.playerCard.opaque))
            
            if let source = model.currentItem?.artist {
                Text("再生元: \(source)")
                    .font(.caption)
                    .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 12)
    }
    
    private var upNextSection: some View {
        ForEach(Array(model.controller.queueItems.enumerated()), id: \.element.id) { index, item in
            QueueItemRowView(
                item: item,
                isCurrentlyPlaying: item.id == model.currentItem?.id,
                showsDragHandle: stateManager.isQueueEditMode,
                onTap: {
                    // Tap on queue item - could show context menu or highlight
                    // Queue items are "up next" - they'll play when current finishes
                }
            )
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
    }
    
    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Seek slider
            TimingIndicator(spacing: 8)
                .padding(.horizontal, ViewConst.playerCardPaddings - ElasticSliderConfig.playbackProgress.growth)
            
            // Playback buttons
            PlayerButtons(spacing: size.width * 0.14)
                .padding(.horizontal, ViewConst.playerCardPaddings)
            
            // Volume slider
            VolumeSlider()
                .padding(.horizontal, 8)
            
            // Footer buttons
            footerButtons
                .padding(.horizontal, ViewConst.playerCardPaddings)
        }
    }
    
    private var footerButtons: some View {
        HStack(alignment: .top, spacing: size.width * 0.18) {
            // Lyrics button
            Button {
                stateManager.goToLyricsSmall()
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.title2)
            }
            
            // AirPlay button
            VStack(spacing: 6) {
                AirPlayButton()
            }
            
            // Queue button (active)
            Button {
                stateManager.toggleQueue()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .padding(8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .foregroundStyle(Color(Palette.playerCard.opaque))
        .blendMode(.overlay)
    }
    
    // MARK: - Scroll Handling
    
    private func handleScrollChange(_ offset: CGFloat) {
        // History Gate logic
        if stateManager.scrollPhase == .main {
            if offset < -NowPlayingStateManager.historyGateThreshold {
                // Passed threshold - show history
                withAnimation(NowPlayingStateManager.transitionAnimation) {
                    showHistory = true
                    stateManager.scrollPhase = .history
                    stateManager.snapPosition = .snapA
                }
            }
        }
    }
    
    // MARK: - Mock Data
    
    private func mockHistoryItem(index: Int) -> PlaybackItem {
        // This would normally come from playback history
        // For now, return current item as placeholder
        if let current = model.currentItem {
            return current
        }
        // Create a mock item if no current item
        return PlaybackItem(
            id: Int64(index),
            source: .local,
            sourceTrackId: "history-\(index)",
            fileUri: nil,
            artworkUri: nil,
            title: "History Track \(index)",
            artist: "Artist",
            album: nil,
            duration: 180,
            artistId: nil
        )
    }
}

/// Individual queue item row
struct QueueItemRowView: View {
    let item: PlaybackItem
    let isCurrentlyPlaying: Bool
    var showsDragHandle: Bool = false
    var onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            ArtworkImageView(
                artworkUri: item.artworkUri,
                cornerRadius: 6,
                contentMode: .fill
            )
            .frame(width: 56, height: 56)
            
            // Title and Artist
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(isCurrentlyPlaying ? .semibold : .regular)
                    .foregroundStyle(Color(Palette.playerCard.opaque))
                    .lineLimit(1)
                
                if let artist = item.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Drag handle (shown in S4 edit mode)
            if showsDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.body)
                    .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.5))
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Scroll Offset Preference Key

private struct QueueScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
