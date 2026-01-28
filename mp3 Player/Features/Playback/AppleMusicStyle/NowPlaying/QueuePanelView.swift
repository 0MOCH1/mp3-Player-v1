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
//  2.5) QueueModeLabel（固定ヘッダー：PlayingFrom / History） ← ★追加
//  3) CurrentQueue（Queue/Historyで切り替え可能、EdgeFade対象）
//

import SwiftUI
import UniformTypeIdentifiers

struct QueuePanelView: View {
    @Environment(NowPlayingAdapter.self) var model
    let size: CGSize
    let safeArea: EdgeInsets
    let controlsHeight: CGFloat
    var animation: Namespace.ID

    private let bottomEdgeFadeHeight: CGFloat = 40
    private let topEdgeFadeHeight: CGFloat = 10

    // 実際のControls高さ（Visibility考慮）
    private var effectiveControlsHeight: CGFloat {
        model.controlsVisibility == .shown ? controlsHeight + safeArea.bottom + ViewConst.bottomToFooterPadding + 12 : 0
    }

    // Queue/History切り替え用
    @State private var showingHistory: Bool = false

    // ★ DnD並び替え用
    @State private var draggedQueueItem: PlaybackItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Grip用のスペーサー（GripはLayer0で描画される）
            Spacer()
                .frame(height: ViewConst.gripSpaceHeight)
                .padding(.top, safeArea.top)

            // 1) CompactTrackInfo（固定ヘッダー）- v8仕様
            CompactTrackInfoView(animation: animation)
                .padding(.top, ViewConst.contentTopPadding + ViewConst.compactTrackInfoTopOffset)
                .padding(.horizontal, 30)
                .padding(.bottom, 12)

            // 2) QueueControls（固定ヘッダー）- v8仕様: Historyボタン含む
            queueControlsView

            // ★ 2.5) Queue / History ラベル（固定ヘッダー）- mask の外
            queueModeLabelView

            // 3) CurrentQueue/History（スクロール可能、切り替え可能）- EdgeFade 対象
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

    // QueueControls: アイコンのみ、高さ40pt
    private let queueControlButtonHeight: CGFloat = 40

    private var queueControlsView: some View {
        HStack(spacing: 12) {
            // Shuffle ボタン（アイコンのみ）
            Button {
                model.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: queueControlButtonHeight)
                    .background(
                        Capsule()
                            .fill(model.isShuffleEnabled ? .white : .white.opacity(0.15))
                    )
                    .foregroundStyle(model.isShuffleEnabled ? .black : .white)
            }

            // Repeat ボタン（アイコンのみ）
            Button {
                model.cycleRepeat()
            } label: {
                Image(systemName: repeatIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: queueControlButtonHeight)
                    .background(
                        Capsule()
                            .fill(model.repeatMode != .off ? .white : .white.opacity(0.15))
                    )
                    .foregroundStyle(model.repeatMode != .off ? .black : .white)
            }

            // History ボタン（アイコンのみ）- v8仕様: トグルでQueue/History切り替え
            Button {
                showingHistory.toggle()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: queueControlButtonHeight, height: queueControlButtonHeight)
                    .background(
                        Circle()
                            .fill(showingHistory ? .white : .white.opacity(0.15))
                    )
                    .foregroundStyle(showingHistory ? .black : .white)
            }
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }

    private var repeatIcon: String {
        switch model.repeatMode {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    // MARK: - Queue/History Label (固定ヘッダー) ★追加

    private var queueModeLabelView: some View {
        Group {
            if showingHistory {
                Text("History")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 8)

            } else if let currentItem = model.currentItem,
                      let sourceLabel = currentItem.sourceLabel {
                Text("Playing from: \(sourceLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 8)
            } else {
                EmptyView()
            }
        }
        .textCase(nil)
    }

    // MARK: - History List View

    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // ★ ここにあった History ラベルは削除（mask外へ移動済み）

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
                        .padding(.horizontal, 30)
                    }
                }
            }
        }
    }

    // MARK: - CurrentQueue List View

    private var currentQueueListView: some View {
        GeometryReader { proxy in
            List {
                // ★ Section header は削除（mask外へ移動済み）

                if model.queueItems.isEmpty {
                    HStack {
                        Spacer()
                        Text("Queue is empty")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.vertical, 40)
                        Spacer()
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                } else {
                    ForEach(Array(model.queueItems.enumerated()), id: \.element.id) { index, item in
                        QueueRowView(
                            item: item,
                            index: index,
                            onDelete: {
                                // index固定キャプチャを避けて、削除時に最新 index を引き直す
                                if let currentIndex = model.queueItems.firstIndex(where: { $0.id == item.id }) {
                                    model.removeFromQueue(at: currentIndex)
                                }
                            }
                        )
                        .listRowInsets(.init(top: 0, leading: 30, bottom: 0, trailing: 30))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())

                        // ★ ドラッグ開始時に draggedQueueItem をセット
                        .onDrag {
                            draggedQueueItem = item
                            return NSItemProvider(object: String(item.id) as NSString)
                        } preview: {
                            QueueRowView(item: item, index: index, onDelete: {})
                                .frame(width: proxy.size.width - 40)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }

                        .onDrop(
                            of: [UTType.text],
                            delegate: QueueDropDelegate(
                                item: item,
                                items: model.queueItems,
                                draggedItem: $draggedQueueItem,
                                moveAction: { from, to in
                                    model.moveQueue(fromOffsets: IndexSet(integer: from), toOffset: to)
                                }
                            )
                        )
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
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
            .frame(height: topEdgeFadeHeight)

            // 中央は完全表示
            Rectangle()
                .fill(.white)

            // 下部のフェード
            LinearGradient(
                colors: [.white, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: bottomEdgeFadeHeight)
        }
    }
}

// MARK: - QueueDropDelegate

private struct QueueDropDelegate: DropDelegate {
    let item: PlaybackItem
    let items: [PlaybackItem]
    @Binding var draggedItem: PlaybackItem?
    let moveAction: (Int, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem,
              let fromIndex = items.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }),
              fromIndex != toIndex
        else { return }

        withAnimation(.easeInOut(duration: ViewConst.animationDuration)) {
            moveAction(fromIndex, toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
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
        .padding(.vertical, 4)
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
