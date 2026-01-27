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
    
    var body: some View {
        VStack(spacing: 0) {
            // Grip用のスペーサー（GripはLayer0で描画される）
            Spacer()
                .frame(height: ViewConst.gripSpaceHeight)
                .padding(.top, safeArea.top)
            
            // QueuePanel本体
            queueContent
                .mask(edgeFadeMask)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var queueContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // History セクション
                    historySection
                    
                    // CompactTrackInfo（現在再生中）
                    CompactTrackInfoView()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .id("nowPlaying")
                    
                    // QueueControls (Shuffle / Repeat) - sticky相当
                    Section {
                        currentQueueSection
                    } header: {
                        queueControlsView
                    }
                }
                .padding(.bottom, controlsBottomPadding)
            }
            .onAppear {
                // 初期位置: CompactTrackInfoが上端に揃う
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        scrollProxy.scrollTo("nowPlaying", anchor: .top)
                    }
                }
            }
        }
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        Section {
            // TODO: History機能はPlaybackControllerから取得
            // 現在は空のプレースホルダー
            if false { // historyItems.isEmpty の代わり
                Text("No history")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        } header: {
            Text("History")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
    }
    
    // MARK: - QueueControls (Shuffle / Repeat)
    
    private var queueControlsView: some View {
        HStack(spacing: 24) {
            // Shuffle ボタン
            Button {
                model.toggleShuffle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.body.weight(.semibold))
                    Text("Shuffle")
                        .font(.subheadline)
                }
                .foregroundStyle(model.isShuffleEnabled ? .white : .white.opacity(0.5))
            }
            
            // Repeat ボタン
            Button {
                model.cycleRepeat()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: repeatIcon)
                        .font(.body.weight(.semibold))
                    Text(repeatLabel)
                        .font(.subheadline)
                }
                .foregroundStyle(model.repeatMode != .off ? .white : .white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.3))
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
        Group {
            if model.queueItems.isEmpty {
                Text("Queue is empty")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(Array(model.queueItems.enumerated()), id: \.element.id) { index, item in
                    QueueRowView(
                        item: item,
                        isNowPlaying: false,
                        onDelete: {
                            model.removeFromQueue(at: index)
                        }
                    )
                    .padding(.horizontal, 20)
                }
                .onMove { fromOffsets, toOffset in
                    model.startReordering()
                    model.moveQueue(fromOffsets: fromOffsets, toOffset: toOffset)
                    model.endReordering()
                }
            }
        }
    }
    
    // Controls表示時は下部にパディングを追加
    private var controlsBottomPadding: CGFloat {
        model.controlsVisibility == .shown ? 280 : 60
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
    let isNowPlaying: Bool
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
            
            // Reorder handle (常時表示)
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
