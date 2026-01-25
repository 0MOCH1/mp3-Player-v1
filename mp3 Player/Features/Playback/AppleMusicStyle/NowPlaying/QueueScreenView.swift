//
//  QueueScreenView.swift
//  mp3 Player
//
//  Queue view for S3 (small) and S4 (reorder large) states
//  Per PLAYING_SCREEN_SPEC.md sections 6.1-6.10
//  Implements Snap A/B, Phase M/H, History Gate, sticky QueueControls
//

import SwiftUI

struct QueueScreenView: View {
    @Environment(NowPlayingAdapter.self) var model
    @Bindable var stateManager: NowPlayingStateManager
    
    @State private var historyItems: [HistoryDisplayItem] = []
    @State private var scrollPosition: CGFloat = 0
    
    // Anchor IDs for scroll positioning
    private let compactAnchorID = "compactTrackInfo"
    private let historyBottomID = "historyBottom"
    
    var body: some View {
        GeometryReader { geometry in
            queueContent(geometry: geometry)
        }
        .onAppear {
            loadHistory()
            // Per spec 6.2: Initial position is always Snap B
            stateManager.snapPosition = .snapB
        }
    }
    
    @ViewBuilder
    private func queueContent(geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // History section (per spec 6.1, 6.6)
                    historySection
                    
                    // Compact track info as list element (per spec 6.1)
                    CompactTrackInfoListItem()
                        .id(compactAnchorID)
                        .padding(.horizontal, ViewConst.playerCardPaddings)
                        .padding(.vertical, 8)
                    
                    // Queue controls section with sticky header (per spec 6.7)
                    Section {
                        currentQueueSection
                    } header: {
                        QueueControlsView()
                    }
                }
            }
            .onAppear {
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
            // Queue items list
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
        // Adjust offsets relative to full queue
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
                    cornerRadius: 4,
                    contentMode: .fill
                )
                .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.callout)
                        .foregroundStyle(Color(Palette.PlayerCard.opaque))
                        .lineLimit(1)
                    
                    if let artist = item.artist {
                        Text(artist)
                            .font(.footnote)
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
                cornerRadius: 4,
                contentMode: .fill
            )
            .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout)
                    .foregroundStyle(Color(Palette.PlayerCard.opaque))
                    .lineLimit(1)
                
                if let artist = item.artist {
                    Text(artist)
                        .font(.footnote)
                        .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.7))
                        .lineLimit(1)
                }
                
                // Source label (per spec 6.8)
                if let album = item.album {
                    Text("再生元: \(album)")
                        .font(.caption2)
                        .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.5))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if isEditMode {
                // Reorder handle for S4 (per spec 6.8)
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Color(Palette.PlayerCard.opaque).opacity(0.5))
                    .padding(.trailing, 4)
            }
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
