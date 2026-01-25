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
    
    // Anchor IDs for scroll positioning
    private let compactAnchorID = "compactTrackInfo"
    private let historyBottomID = "historyBottom"
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // 1) History section (per spec 6.1, 6.6)
                    historySection
                    
                    // 2) Compact track info as scrollable list item (per spec 6.1)
                    CompactTrackInfoQueueHeader {
                        stateManager.returnToStandard()
                    }
                    .id(compactAnchorID)
                    
                    // 3) Queue controls as sticky header (per spec 6.7)
                    Section {
                        // 4) Current queue section
                        currentQueueSection
                    } header: {
                        QueueControlsView()
                            .background(Color.clear)
                    }
                }
            }
            .onAppear {
                loadHistory()
                // Per spec 6.2: Scroll to Snap B on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo(compactAnchorID, anchor: .top)
                    }
                }
            }
            .onChange(of: stateManager.snapPosition) { _, newPosition in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
    
    // MARK: - History Section
    
    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // History header with clear button (per spec 6.6)
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
            .padding(.horizontal, ViewConst.playerCardPaddings)
            .padding(.vertical, 12)
            
            // History items
            if historyItems.isEmpty {
                // Per spec 6.10: Empty history shows section but empty
                Color.clear.frame(height: 8)
            } else {
                ForEach(historyItems) { item in
                    HistoryItemRow(item: item) {
                        playFromHistory(item)
                    }
                }
            }
            
            // Marker for Snap A position
            Color.clear
                .frame(height: 1)
                .id(historyBottomID)
        }
    }
    
    // MARK: - Current Queue Section
    
    @ViewBuilder
    private var currentQueueSection: some View {
        let queueItems = model.controller.queueItems
        let currentIndex = getCurrentIndex()
        
        // Filter to only show items after current (per spec 6.8)
        let upNextItems = Array(queueItems.dropFirst(currentIndex + 1))
        
        // Queue section header
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 12)
        
        if upNextItems.isEmpty {
            // Per spec 6.10: Empty queue message
            VStack(spacing: 16) {
                Text("キューが空です")
                    .font(.headline)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            // Separator line (visible in S4)
            if stateManager.currentState == .queueReorderLarge {
                Rectangle()
                    .fill(Color(Palette.PlayerCard.opaque).opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, ViewConst.playerCardPaddings)
            }
            
            // Queue items list with reorder support
            ForEach(Array(upNextItems.enumerated()), id: \.element.id) { index, item in
                QueueItemRow(
                    item: item,
                    isEditMode: stateManager.isQueueEditMode,
                    onDelete: {
                        deleteQueueItem(at: currentIndex + 1 + index)
                    }
                )
            }
            .onMove { fromOffsets, toOffset in
                moveQueueItems(fromOffsets: fromOffsets, toOffset: toOffset, baseIndex: currentIndex + 1)
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
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ArtworkImageView(
                    artworkUri: item.artworkUri,
                    cornerRadius: 6,
                    contentMode: .fill
                )
                .frame(width: 56, height: 56)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(Color(Palette.PlayerCard.opaque))
                        .lineLimit(1)
                    
                    if let artist = item.artist {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, ViewConst.playerCardPaddings)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct QueueItemRow: View {
    let item: PlaybackItem
    let isEditMode: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ArtworkImageView(
                artworkUri: item.artworkUri,
                cornerRadius: 6,
                contentMode: .fill
            )
            .frame(width: 56, height: 56)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque))
                    .lineLimit(1)
                
                if let artist = item.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Reorder handle always visible (per spec 6.8)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.5))
                .padding(.trailing, 4)
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
            }
        }
    }
}
