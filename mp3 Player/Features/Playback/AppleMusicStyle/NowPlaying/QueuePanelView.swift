//
//  QueuePanelView.swift
//  mp3 Player
//
//  FullPlayer内のQueueモードで表示されるキューパネル
//  Layer1: ContentPanel に属する
//
//  v8仕様に基づく構造:
//  1) CompactTrackInfo（固定ヘッダー）
//  2) QueueControls（固定ヘッダー、Historyボタン含む）
//  3) CurrentQueue（Queue/Historyで切り替え可能）
//

import SwiftUI
import UniformTypeIdentifiers

struct QueuePanelView: View {
    @Environment(NowPlayingAdapter.self) var model
    let size: CGSize
    let safeArea: EdgeInsets
    let controlsHeight: CGFloat
    var animation: Namespace.ID
    
    private let edgeFadeHeight: CGFloat = 40
    
    // 実際のControls高さ（Visibility考慮）
    private var effectiveControlsHeight: CGFloat {
        model.controlsVisibility == .shown ? controlsHeight + safeArea.bottom + ViewConst.bottomToFooterPadding : 0
    }
    
    // Queue/History切り替え用
    @State private var showingHistory: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Grip用のスペーサー（GripはLayer0で描画される）
            Spacer()
                .frame(height: ViewConst.gripSpaceHeight)
                .padding(.top, safeArea.top)
            
            // 1) CompactTrackInfo（固定ヘッダー）- v8仕様
            CompactTrackInfoView(animation: animation)
                .padding(.horizontal, 20)
                .padding(.top, ViewConst.contentTopPadding + ViewConst.compactTrackInfoTopOffset)
            
            // 2) QueueControls（固定ヘッダー）- v8仕様: Historyボタン含む
            queueControlsView
            
            // 3) CurrentQueue/History（スクロール可能、切り替え可能）
            ZStack {
                if showingHistory {
                    historyListView
                        .transition(.opacity)
                } else {
                    currentQueueListView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: ViewConst.animationDuration), value: showingHistory)
            .mask(edgeFadeMask)
            .padding(.bottom, effectiveControlsHeight)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - QueueControls (固定ヘッダー)
    // v8仕様: Shuffle / Repeat / History ボタン
    
    private var queueControlsView: some View {
        HStack(spacing: 12) {
            // Shuffle ボタン
            Button {
                model.toggleShuffle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.body.weight(.semibold))
                    Text("Shuffle")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, ViewConst.queueControlsHorizontalPadding)
                .padding(.vertical, ViewConst.queueControlsVerticalPadding)
                .background(
                    Capsule()
                        .fill(model.isShuffleEnabled ? .white : .white.opacity(0.15))
                )
                .foregroundStyle(model.isShuffleEnabled ? .black : .white)
            }
            
            // Repeat ボタン
            Button {
                model.cycleRepeat()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: repeatIcon)
                        .font(.body.weight(.semibold))
                    Text(repeatLabel)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, ViewConst.queueControlsHorizontalPadding)
                .padding(.vertical, ViewConst.queueControlsVerticalPadding)
                .background(
                    Capsule()
                        .fill(model.repeatMode != .off ? .white : .white.opacity(0.15))
                )
                .foregroundStyle(model.repeatMode != .off ? .black : .white)
            }
            
            // History ボタン - v8仕様: トグルでQueue/History切り替え
            Button {
                showingHistory.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.body.weight(.semibold))
                    Text("History")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, ViewConst.queueControlsHorizontalPadding)
                .padding(.vertical, ViewConst.queueControlsVerticalPadding)
                .background(
                    Capsule()
                        .fill(showingHistory ? .white : .white.opacity(0.15))
                )
                .foregroundStyle(showingHistory ? .black : .white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
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
    
    // MARK: - History List View
    
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // History ラベル
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
                        .padding(.vertical, 40)
                } else {
                    ForEach(model.historyItems) { item in
                        HistoryRowView(item: item) {
                            // 履歴の曲をタップして再生開始 → Queue表示に戻る
                            model.playFromHistory(item: item)
                            showingHistory = false
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - CurrentQueue List View
    
    private var currentQueueListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Source ラベル（セクションラベルとして表示）- v8仕様
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
                    // Reorderable list - v8仕様: 常に並び替え可能
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
                            QueueRowView(item: item, index: index, onDelete: {})
                                .frame(width: size.width - 40)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                        .onDrop(of: [.text], delegate: QueueDropDelegate(
                            item: item,
                            items: model.queueItems,
                            draggedItem: nil,
                            moveAction: { from, to in
                                model.moveQueue(fromOffsets: IndexSet(integer: from), toOffset: to)
                            }
                        ))
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

// MARK: - QueueDropDelegate

private struct QueueDropDelegate: DropDelegate {
    let item: PlaybackItem
    let items: [PlaybackItem]
    let draggedItem: PlaybackItem?
    let moveAction: (Int, Int) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let fromIndex = items.firstIndex(where: { $0.id == draggedItem?.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }),
              fromIndex != toIndex else { return }
        
        moveAction(fromIndex, toIndex > fromIndex ? toIndex + 1 : toIndex)
    }
}

// MARK: - QueueRowView (TrackRowView踏襲、RoundedRectangle Artwork)

private struct QueueRowView: View {
    let item: PlaybackItem
    let index: Int
    let onDelete: () -> Void
    
    private let artworkSize: CGFloat = 48
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork (RoundedRectangle = 角丸あり、cornerRadius: 4)
            if let artworkUri = item.artworkUri {
                ArtworkImageView(artworkUri: artworkUri, cornerRadius: ViewConst.queueArtworkCornerRadius, contentMode: .fill)
                    .frame(width: artworkSize, height: artworkSize)
            } else {
                RoundedRectangle(cornerRadius: ViewConst.queueArtworkCornerRadius)
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

// MARK: - HistoryRowView (RoundedRectangle Artwork)
// v8仕様: 履歴内の曲をタップして再生を始める

private struct HistoryRowView: View {
    let item: HistoryItem
    let onTap: () -> Void
    
    private let artworkSize: CGFloat = 48
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Artwork (RoundedRectangle = 角丸あり)
                if let artworkUri = item.artworkUri {
                    ArtworkImageView(artworkUri: artworkUri, cornerRadius: ViewConst.queueArtworkCornerRadius, contentMode: .fill)
                        .frame(width: artworkSize, height: artworkSize)
                } else {
                    RoundedRectangle(cornerRadius: ViewConst.queueArtworkCornerRadius)
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
        .buttonStyle(.plain)
    }
}
