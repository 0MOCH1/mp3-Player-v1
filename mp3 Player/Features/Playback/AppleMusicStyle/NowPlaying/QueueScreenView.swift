//
//  QueueScreenView.swift
//  mp3 Player
//

import SwiftUI

/// Queue screen view for states S3 (queue small) and S4 (queue reorder)
/// Per spec section 6.1, structure (top to bottom):
/// 1) 履歴（History）
/// 2) 縮小楽曲情報（CompactTrackInfo）- scrollable list item
/// 3) キューコントロール（QueueControls）- sticky header
/// 4) 現在のキュー（CurrentQueue）
struct QueueScreenView: View {
    @Environment(NowPlayingAdapter.self) var model
    let stateManager: NowPlayingStateManager
    var size: CGSize
    var safeArea: EdgeInsets
    
    @State private var outerScrollOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Grip indicator
            grip
                .padding(.top, safeArea.top)
            
            // Queue Content with proper structure per spec
            queueContent
            
            // Bottom controls (shown in S3, hidden in S4 per spec section 4.2)
            if stateManager.currentState == .queueSmall {
                bottomControls
                    .padding(.bottom, safeArea.bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(NowPlayingStateManager.transitionAnimation, value: stateManager.currentState)
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
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        // History Section (visible when scrolled up per spec section 6.4)
                        if stateManager.scrollPhase == .history {
                            historySection
                                .id("history")
                        }
                        
                        // CompactTrackInfo - part of scrollable list per spec section 1.1
                        compactTrackInfoRow
                            .id("compactTrackInfo")
                        
                        // QueueControls + CurrentQueue in a Section for sticky header per spec section 6.7
                        Section {
                            currentQueueSection
                        } header: {
                            QueueControlsView()
                                .background(.ultraThinMaterial.opacity(0.5))
                        }
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
                .onAppear {
                    // Per spec section 6.2: Initial position is Snap B (compactTrackInfo at top)
                    proxy.scrollTo("compactTrackInfo", anchor: .top)
                }
            }
        }
    }
    
    /// Compact track info as a scrollable list item per spec section 1.1
    private var compactTrackInfoRow: some View {
        HStack(spacing: 12) {
            // Artwork thumbnail (48x48)
            ArtworkImageView(
                artworkUri: model.display.artworkUri,
                cornerRadius: 8,
                contentMode: .fill
            )
            .frame(width: NowPlayingStateManager.compactArtworkSize, 
                   height: NowPlayingStateManager.compactArtworkSize)
            
            // Title and Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(model.display.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(Palette.playerCard.opaque))
                    .lineLimit(1)
                
                if let subtitle = model.display.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, ViewConst.playerCardPaddings)
        .frame(height: NowPlayingStateManager.compactHeaderHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap to return to S0 per spec section 3.1
            withAnimation(NowPlayingStateManager.transitionAnimation) {
                stateManager.goToStandard()
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
                
                // Per spec section 6.6: 操作：全消去のみ
                Button("消去") {
                    // Clear history action
                }
                .font(.subheadline)
                .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.7))
            }
            .padding(.horizontal, ViewConst.playerCardPaddings)
            .padding(.vertical, 12)
            
            // History items (would come from PlaybackController)
            // Per spec section 6.10: 履歴空：空表示（セクションは表示）
            ForEach(0..<3, id: \.self) { index in
                QueueItemRowView(
                    item: mockHistoryItem(index: index),
                    isCurrentlyPlaying: false,
                    showsDragHandle: false,
                    onDragStart: {},
                    onDragEnd: {},
                    onTap: {}
                )
            }
        }
    }
    
    private var currentQueueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header per spec section 6.8: ラベルに追加元を付記
            VStack(alignment: .leading, spacing: 4) {
                Text("次に再生")
                    .font(.headline)
                    .foregroundStyle(Color(Palette.playerCard.opaque))
                
                if let album = model.currentItem?.album {
                    Text("再生元: \(album)")
                        .font(.caption)
                        .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ViewConst.playerCardPaddings)
            .padding(.vertical, 12)
            
            // Queue items per spec section 6.8
            // Per spec section 6.10: キュー空：キューが空です
            if model.controller.queueItems.isEmpty {
                Text("キューが空です")
                    .font(.body)
                    .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(Array(model.controller.queueItems.enumerated()), id: \.element.id) { index, item in
                    QueueItemRowView(
                        item: item,
                        isCurrentlyPlaying: false, // Current item is shown in compactTrackInfo per spec
                        showsDragHandle: true, // Always show drag handle per spec section 6.8
                        onDragStart: {
                            // S3 → S4 on drag start per spec section 3.3
                            if stateManager.currentState == .queueSmall {
                                withAnimation(NowPlayingStateManager.transitionAnimation) {
                                    stateManager.goToQueueReorder()
                                }
                            }
                        },
                        onDragEnd: {
                            // S4 → S3 on drag end per spec section 3.3
                            if stateManager.currentState == .queueReorderLarge {
                                withAnimation(NowPlayingStateManager.transitionAnimation) {
                                    stateManager.goToQueueSmall()
                                }
                            }
                        },
                        onTap: {}
                    )
                    // Per spec section 6.8: 左スワイプ削除：確認なし（即時削除）
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            model.controller.removeFromQueue(at: index)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
                .onMove { fromOffsets, toOffset in
                    model.controller.moveQueue(fromOffsets: fromOffsets, toOffset: toOffset)
                }
            }
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
                withAnimation(NowPlayingStateManager.transitionAnimation) {
                    stateManager.goToLyricsSmall()
                }
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.title2)
            }
            
            // AirPlay button
            VStack(spacing: 6) {
                AirPlayButton()
            }
            
            // Queue button (active state) with state indicator per spec section 6.9
            ZStack(alignment: .topTrailing) {
                Button {
                    withAnimation(NowPlayingStateManager.transitionAnimation) {
                        stateManager.toggleQueue()
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                
                // Show shuffle/repeat indicator per spec section 6.9
                if model.controller.isShuffleEnabled || model.controller.repeatMode != .off {
                    Image(systemName: model.controller.isShuffleEnabled ? "shuffle" : "repeat")
                        .font(.system(size: 8))
                        .padding(3)
                        .background(Color.white.opacity(0.3))
                        .clipShape(Circle())
                        .offset(x: 12, y: -4)
                }
            }
        }
        .foregroundStyle(Color(Palette.playerCard.opaque))
        .blendMode(.overlay)
    }
    
    // MARK: - Scroll Handling per spec section 6.4-6.5
    
    private func handleScrollChange(_ offset: CGFloat) {
        // History Gate logic per spec section 6.5
        if stateManager.scrollPhase == .main {
            if offset < -NowPlayingStateManager.historyGateThreshold {
                // Passed threshold - switch to Phase H
                withAnimation(NowPlayingStateManager.transitionAnimation) {
                    stateManager.scrollPhase = .history
                    stateManager.snapPosition = .snapA
                }
            }
        }
    }
    
    // MARK: - Mock Data
    
    private func mockHistoryItem(index: Int) -> PlaybackItem {
        if let current = model.currentItem {
            return current
        }
        return PlaybackItem(
            id: Int64(index),
            source: .local,
            sourceTrackId: "history-\(index)",
            fileUri: nil,
            artworkUri: nil,
            title: "履歴トラック \(index + 1)",
            artist: "アーティスト",
            album: nil,
            duration: 180,
            artistId: nil
        )
    }
}

/// Individual queue item row with drag handle support
struct QueueItemRowView: View {
    let item: PlaybackItem
    let isCurrentlyPlaying: Bool
    var showsDragHandle: Bool = false
    var onDragStart: () -> Void
    var onDragEnd: () -> Void
    var onTap: () -> Void
    
    @State private var hasDragStarted: Bool = false
    
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
            
            // Drag handle per spec section 6.8: 並び替え：常に可能（Reorder handle）
            if showsDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.body)
                    .foregroundStyle(Color(Palette.playerCard.opaque).opacity(0.5))
                    .padding(.trailing, 4)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                // Only call onDragStart once when drag begins
                                if !hasDragStarted {
                                    hasDragStarted = true
                                    onDragStart()
                                }
                            }
                            .onEnded { _ in
                                hasDragStarted = false
                                onDragEnd()
                            }
                    )
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
