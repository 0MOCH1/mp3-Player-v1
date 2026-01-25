//
//  QueueScreenView.swift
//  mp3 Player
//
//  Queue view for S3 (small) and S4 (reorder large) states
//  Per PLAYING_SCREEN_SPEC.md sections 6.1-6.10
//  Based on reference images S3, SnapA/SnapB.PNG and S4.PNG
//
//  Structure (top to bottom, per spec 6.1):
//  1) History section
//  2) Compact track info (scrollable list item)
//  3) Queue controls (sticky header)
//  4) Current queue list
//

import SwiftUI

struct QueueScreenView: View {
    @Environment(NowPlayingAdapter.self) var model
    @Bindable var stateManager: NowPlayingStateManager
    
    @State private var historyItems: [HistoryDisplayItem] = []
    @State private var didScrollToInitial = false
    
    // Anchor IDs for scroll positioning
    private let compactAnchorID = "compactTrackInfo"
    private let historyBottomID = "historyBottom"
    
    // Artwork size matching TrackRowView (48pt)
    private let artworkSize: CGFloat = 48
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                // 1) History section (per spec 6.1, 6.6)
                Section {
                    if historyItems.isEmpty {
                        // Per spec 6.10: Empty history shows section but empty
                        Color.clear.frame(height: 8)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(historyItems) { item in
                            HistoryItemRow(item: item, artworkSize: artworkSize) {
                                playFromHistory(item)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                } header: {
                    HStack {
                        Text("履歴")
                            .font(.headline)
                            .foregroundStyle(Color(Palette.PlayerCard.opaque))
                        
                        Spacer()
                        
                        if !historyItems.isEmpty {
                            Button("消去") {
                                clearHistory()
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.7))
                        }
                    }
                    .textCase(nil)
                }
                
                // Marker for Snap A position
                Color.clear
                    .frame(height: 1)
                    .id(historyBottomID)
                    .listRowBackground(Color.clear)
                
                // 2) Compact track info as scrollable list item (per spec 6.1)
                CompactTrackInfoQueueHeader {
                    stateManager.returnToStandard()
                }
                .id(compactAnchorID)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                
                // 3) Queue controls (per spec 6.7)
                QueueControlsView()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                
                // 4) Current queue section header
                Section {
                    currentQueueItems
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("再生を続ける")
                            .font(.headline)
                            .foregroundStyle(Color(Palette.PlayerCard.opaque))
                        
                        // Source label (per spec 6.8)
                        if let currentItem = model.currentItem, let album = currentItem.album {
                            Text("再生元: \(album)")
                                .font(.subheadline)
                                .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.6))
                        }
                    }
                    .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(stateManager.isQueueEditMode ? .active : .inactive))
            .onAppear {
                loadHistory()
                // Per spec 6.2: Scroll to Snap B immediately on appear
                if !didScrollToInitial {
                    proxy.scrollTo(compactAnchorID, anchor: .top)
                    didScrollToInitial = true
                }
            }
            .onChange(of: stateManager.snapPosition) { _, newPosition in
                withAnimation(.linear(duration: 0.25)) {
                    switch newPosition {
                    case .snapA:
                        proxy.scrollTo(historyBottomID, anchor: .bottom)
                    case .snapB:
                        proxy.scrollTo(compactAnchorID, anchor: .top)
                    }
                }
            }
        }
    }
    
    // MARK: - Current Queue Items
    
    @ViewBuilder
    private var currentQueueItems: some View {
        let queueItems = model.controller.queueItems
        let currentIndex = getCurrentIndex()
        
        // Filter to only show items after current (per spec 6.8)
        let upNextItems = Array(queueItems.dropFirst(currentIndex + 1))
        
        if upNextItems.isEmpty {
            // Per spec 6.10: Empty queue message
            VStack(spacing: 16) {
                Text("キューが空です")
                    .font(.headline)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .listRowBackground(Color.clear)
        } else {
            // Queue items with reorder support
            ForEach(upNextItems) { item in
                QueueItemRow(
                    item: item,
                    artworkSize: artworkSize,
                    onDelete: {
                        if let index = queueItems.firstIndex(where: { $0.id == item.id }) {
                            deleteQueueItem(at: index)
                        }
                    }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .onMove { fromOffsets, toOffset in
                moveQueueItems(fromOffsets: fromOffsets, toOffset: toOffset, baseIndex: currentIndex + 1)
            }
            .onDelete { offsets in
                offsets.forEach { index in
                    deleteQueueItem(at: currentIndex + 1 + index)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentIndex() -> Int {
        guard let currentItem = model.currentItem else { return -1 }
        return model.controller.queueItems.firstIndex(where: { $0.id == currentItem.id }) ?? -1
    }
    
    private func loadHistory() {
        Task {
            historyItems = await model.controller.fetchHistoryItems(limit: 50)
        }
    }
    
    private func clearHistory() {
        historyItems = []
        model.controller.clearHistory()
    }
    
    private func playFromHistory(_ item: HistoryDisplayItem) {
        model.controller.playFromHistory(source: item.source, sourceTrackId: item.sourceTrackId)
    }
    
    private func deleteQueueItem(at index: Int) {
        model.controller.removeFromQueue(at: index)
    }
    
    private func moveQueueItems(fromOffsets: IndexSet, toOffset: Int, baseIndex: Int) {
        let adjustedFromOffsets = IndexSet(fromOffsets.map { $0 + baseIndex })
        let adjustedToOffset = toOffset + baseIndex
        model.controller.moveQueue(fromOffsets: adjustedFromOffsets, toOffset: adjustedToOffset)
    }
}

// MARK: - Supporting Views

struct HistoryItemRow: View {
    let item: HistoryDisplayItem
    let artworkSize: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ArtworkImageView(
                    artworkUri: item.artworkUri,
                    cornerRadius: 6,
                    contentMode: .fill
                )
                .frame(width: artworkSize, height: artworkSize)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.callout)
                        .foregroundStyle(Color(Palette.PlayerCard.opaque))
                        .lineLimit(1)
                    
                    if let artist = item.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, ViewConst.playerCardPaddings)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct QueueItemRow: View {
    let item: PlaybackItem
    let artworkSize: CGFloat
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ArtworkImageView(
                artworkUri: item.artworkUri,
                cornerRadius: 6,
                contentMode: .fill
            )
            .frame(width: artworkSize, height: artworkSize)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.callout)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque))
                    .lineLimit(1)
                
                if let artist = item.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
