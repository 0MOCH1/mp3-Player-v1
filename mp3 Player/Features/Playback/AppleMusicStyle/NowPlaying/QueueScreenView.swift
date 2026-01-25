//
//  QueueScreenView.swift
//  mp3 Player
//
//  Queue view for S3 (small) and S4 (reorder large) states
//  Per PLAYING_SCREEN_SPEC.md sections 6.1-6.10
//
//  Structure (top to bottom, per spec 6.1):
//  1) History section
//  2) CompactTrackInfo (scrollable list item)
//  3) QueueControls (sticky header - always visible)
//  4) CurrentQueue list
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
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // 1) History section (per spec 6.1, 6.6)
                    historySection
                    
                    // Marker for Snap A position
                    Color.clear
                        .frame(height: 1)
                        .id(historyBottomID)
                    
                    // 2) CompactTrackInfo as scrollable list item (per spec 6.1)
                    CompactTrackInfoQueueHeader {
                        stateManager.returnToStandard()
                    }
                    .id(compactAnchorID)
                    
                    // 3) QueueControls as sticky header (per spec 6.7)
                    // 4) CurrentQueue as section content
                    Section {
                        currentQueueSection
                    } header: {
                        QueueControlsView()
                            .background(Color.clear)
                    }
                }
            }
            .onAppear {
                loadHistory()
                // Per spec 6.2: Initial position is Snap B
                if !didScrollToInitial {
                    DispatchQueue.main.async {
                        proxy.scrollTo(compactAnchorID, anchor: .top)
                        didScrollToInitial = true
                    }
                }
            }
            .onChange(of: stateManager.snapPosition) { _, newPosition in
                withAnimation(.smooth(duration: 0.35)) {
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
        
        // Separator line (visible in S4 per reference)
        if stateManager.currentState == .queueReorderLarge {
            Rectangle()
                .fill(Color(Palette.PlayerCard.opaque).opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, ViewConst.playerCardPaddings)
        }
        
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
            // Queue items with reorder handle (per spec 6.8)
            ForEach(upNextItems) { item in
                let itemIndex = upNextItems.firstIndex(where: { $0.id == item.id }) ?? 0
                QueueItemRow(
                    item: item,
                    onDelete: {
                        deleteQueueItem(at: currentIndex + 1 + itemIndex)
                    },
                    onDragStart: {
                        // Per spec 3.3: Reorder handle drag starts S4
                        stateManager.enterQueueReorderMode()
                    }
                )
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
    let onDelete: () -> Void
    let onDragStart: () -> Void
    
    @State private var didStartDrag = false
    
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
            
            // Reorder handle (per spec 6.8: 並び替え：常に可能)
            Image(systemName: "line.3.horizontal")
                .font(.title3)
                .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.5))
                .padding(.trailing, 4)
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { _ in
                            if !didStartDrag {
                                didStartDrag = true
                                onDragStart()
                            }
                        }
                        .onEnded { _ in
                            didStartDrag = false
                        }
                )
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // Per spec 6.8: Left swipe delete without confirmation
            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
            }
        }
    }
}
