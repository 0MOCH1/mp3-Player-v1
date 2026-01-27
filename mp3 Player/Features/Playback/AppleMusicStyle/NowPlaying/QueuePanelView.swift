//
//  QueuePanelView.swift
//  mp3 Player
//
//  FullPlayer内のQueueモードで表示されるキューパネル
//  Layer1: ContentPanel に属する
//

import SwiftUI

struct QueuePanelView: View {
    @Environment(NowPlayingAdapter.self) var model
    let size: CGSize
    let safeArea: EdgeInsets
    
    private let compactTrackInfoHeight: CGFloat = 100
    private let edgeFadeHeight: CGFloat = 40
    
    // Controls の高さ（シークバー上端まで）
    private var controlsHeight: CGFloat {
        model.controlsVisibility == .shown ? 280 : 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Grip用のスペーサー（GripはLayer0で描画される）
            Spacer()
                .frame(height: ViewConst.gripSpaceHeight)
                .padding(.top, safeArea.top)
            
            // QueuePanel本体（EdgeFade適用、ただしQueueControlsは回避）
            ZStack(alignment: .top) {
                // スクロールコンテンツ
                queueContent
                    .mask(edgeFadeMask)
                
                // QueueControls（EdgeFade回避のため別レイヤ）
                VStack {
                    // CompactTrackInfoの高さ分スペース
                    Spacer().frame(height: compactTrackInfoHeight + 16)
                    
                    // QueueControls (Shuffle / Repeat) - Capsule スタイル
                    queueControlsView
                    
                    Spacer()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var queueContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // History セクション
                    historySection
                    
                    // CompactTrackInfo（現在再生中）
                    CompactTrackInfoView()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .id("nowPlaying")
                    
                    // QueueControls用のスペース（実際のボタンは別レイヤ）
                    Spacer().frame(height: 60)
                    
                    // CurrentQueue セクション
                    currentQueueSection
                }
                .padding(.bottom, controlsHeight + 60)
            }
            .scrollPosition(id: .constant("nowPlaying"), anchor: .top)
        }
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            
            if model.historyItems.isEmpty {
                Text("No history")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(model.historyItems) { item in
                    HistoryRowView(item: item)
                        .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - QueueControls (Shuffle / Repeat) - Capsule Style
    
    private var queueControlsView: some View {
        HStack(spacing: 16) {
            // Shuffle ボタン - Capsule
            Button {
                model.toggleShuffle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.body.weight(.semibold))
                    Text("Shuffle")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(model.isShuffleEnabled ? .white : .white.opacity(0.15))
                )
                .foregroundStyle(model.isShuffleEnabled ? .black : .white)
            }
            
            // Repeat ボタン - Capsule
            Button {
                model.cycleRepeat()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: repeatIcon)
                        .font(.body.weight(.semibold))
                    Text(repeatLabel)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(model.repeatMode != .off ? .white : .white.opacity(0.15))
                )
                .foregroundStyle(model.repeatMode != .off ? .black : .white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
    
    private var repeatIcon: String {
        switch model.repeatMode {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    private var repeatLabel: String {
        switch model.repeatMode {
        case .off: return "Repeat"
        case .all: return "All"
        case .one: return "One"
        }
    }
    
    // MARK: - CurrentQueue Section
    
    private var currentQueueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Source ラベル（リストのラベルとして表示）
            if let currentItem = model.currentItem, let sourceLabel = currentItem.sourceLabel {
                Text("Playing from \(sourceLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            
            if model.queueItems.isEmpty {
                Text("Queue is empty")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                // Reorderable list using draggable/dropDestination
                ForEach(Array(model.queueItems.enumerated()), id: \.element.id) { index, item in
                    QueueRowView(
                        item: item,
                        index: index,
                        onDelete: {
                            model.removeFromQueue(at: index)
                        }
                    )
                    .padding(.horizontal, 20)
                    .draggable(String(item.id)) {
                        // Drag preview
                        Text(item.title)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    .dropDestination(for: String.self) { items, location in
                        guard let draggedIdString = items.first,
                              let draggedId = Int64(draggedIdString),
                              let fromIndex = model.queueItems.firstIndex(where: { $0.id == draggedId }) else {
                            return false
                        }
                        if fromIndex != index {
                            model.startReordering()
                            model.moveQueue(fromOffsets: IndexSet(integer: fromIndex), toOffset: fromIndex < index ? index + 1 : index)
                            model.endReordering()
                        }
                        return true
                    }
                }
            }
        }
    }
    
    // EdgeFade効果用のマスク
    private var edgeFadeMask: some View {
        VStack(spacing: 0) {
            // 上部のフェード
            LinearGradient(
                colors: [.clear, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: edgeFadeHeight)
            
            // 中央は完全表示
            Rectangle()
                .fill(.white)
            
            // 下部のフェード
            LinearGradient(
                colors: [.white, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: edgeFadeHeight)
        }
    }
}

// MARK: - QueueRowView (TrackRowView踏襲)

private struct QueueRowView: View {
    let item: PlaybackItem
    let index: Int
    let onDelete: () -> Void
    
    private let artworkSize: CGFloat = 48
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork (Rectangle = 角丸なし)
            if let artworkUri = item.artworkUri {
                ArtworkImageView(artworkUri: artworkUri, cornerRadius: 0, contentMode: .fill)
                    .frame(width: artworkSize, height: artworkSize)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: artworkSize, height: artworkSize)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }
            
            // Title + Artist（Sourceは行ではなくセクションラベルで表示）
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if let artist = item.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Reorder handle
            Image(systemName: "line.3.horizontal")
                .font(.body)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - HistoryRowView

private struct HistoryRowView: View {
    let item: HistoryItem
    
    private let artworkSize: CGFloat = 48
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork (Rectangle = 角丸なし)
            if let artworkUri = item.artworkUri {
                ArtworkImageView(artworkUri: artworkUri, cornerRadius: 0, contentMode: .fill)
                    .frame(width: artworkSize, height: artworkSize)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: artworkSize, height: artworkSize)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }
            
            // Title + Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if let artist = item.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - PreferenceKeys for Scroll Tracking

private struct NowPlayingPositionPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
