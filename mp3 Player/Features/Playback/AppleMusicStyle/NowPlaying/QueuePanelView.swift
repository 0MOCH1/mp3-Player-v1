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
    let controlsHeight: CGFloat
    var animation: Namespace.ID
    
    private let compactTrackInfoHeight: CGFloat = 100
    private let edgeFadeHeight: CGFloat = 40
    
    // 実際のControls高さ（Visibility考慮）- v7仕様に基づき動的に変更
    private var effectiveControlsHeight: CGFloat {
        model.controlsVisibility == .shown ? controlsHeight + safeArea.bottom + ViewConst.bottomToFooterPadding : 0
    }
    
    @State private var scrolledID: String? = nil
    @State private var hasSetInitialPosition: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Grip用のスペーサー（GripはLayer0で描画される）
            Spacer()
                .frame(height: ViewConst.gripSpaceHeight)
                .padding(.top, safeArea.top)
            
            // QueuePanel本体
            ZStack(alignment: .top) {
                // スクロールコンテンツ（EdgeFade適用）
                queueScrollContent
                    .mask(edgeFadeMask)
                
                // QueueControls - EdgeFadeの外側に配置（フェードに巻き込まれない）
                VStack {
                    Spacer()
                        .frame(height: compactTrackInfoHeight + 20) // CompactTrackInfo後に配置
                    queueControlsView
                    Spacer()
                }
                .allowsHitTesting(true)
            }
            .padding(.bottom, effectiveControlsHeight)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            // 初期位置をCompactTrackInfoに即座に設定（アニメーションなし）
            if !hasSetInitialPosition {
                scrolledID = "nowPlaying"
                hasSetInitialPosition = true
            }
        }
    }
    
    private var queueScrollContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // History セクション
                    historySection
                    
                    // CompactTrackInfo（現在再生中）- 10pt上に配置
                    CompactTrackInfoView(animation: animation)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .padding(.top, ViewConst.compactTrackInfoTopOffset)
                        .id("nowPlaying")
                    
                    // QueueControlsの占有スペース（実際のQueueControlsはEdgeFade外に配置）
                    Spacer()
                        .frame(height: 60)
                    
                    // CurrentQueue セクション
                    currentQueueSection
                }
            }
            .scrollPosition(id: $scrolledID, anchor: .top)
            .onChange(of: scrolledID) { oldValue, newValue in
                // スクロール位置の変更を追跡
            }
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
    
    // MARK: - QueueControls (Shuffle / Repeat) - v7仕様
    // EdgeFade外、背景なし、ボタンサイズ拡大
    
    private var queueControlsView: some View {
        HStack(spacing: 16) {
            // Shuffle ボタン - Capsule、サイズ拡大（縦+5pt、横+20pt）
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
            
            // Repeat ボタン - Capsule、サイズ拡大
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
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
        // 背景なし（v7仕様）
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
            // Source ラベル（セクションラベルとして表示）
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
                // Reorderable list using ForEach with onMove
                ForEach(Array(model.queueItems.enumerated()), id: \.element.id) { index, item in
                    QueueRowView(
                        item: item,
                        index: index,
                        onDelete: {
                            model.removeFromQueue(at: index)
                        }
                    )
                    .padding(.horizontal, 20)
                    .onDrag {
                        model.startReordering()
                        return NSItemProvider(object: String(item.id) as NSString)
                    }
                    .onDrop(of: [.text], delegate: QueueDropDelegate(
                        item: item,
                        items: model.queueItems,
                        draggedItem: nil,
                        moveAction: { from, to in
                            model.moveQueue(fromOffsets: IndexSet(integer: from), toOffset: to)
                            model.endReordering()
                        }
                    ))
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

private struct HistoryRowView: View {
    let item: HistoryItem
    
    private let artworkSize: CGFloat = 48
    
    var body: some View {
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
}
