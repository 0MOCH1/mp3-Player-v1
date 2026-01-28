import SwiftUI

/// Standard context menu items for tracks throughout the app
struct TrackContextMenu {
    let trackId: Int64
    let trackTitle: String
    let source: String
    let sourceTrackId: String
    let isFavorite: Bool
    let playbackController: PlaybackController?
    let onAddToPlaylist: (() -> Void)?
    let onShowAlbum: (() -> Void)?
    let onShowArtist: (() -> Void)?
    let onDelete: (() -> Void)?
    let onToggleFavorite: (() -> Void)?
    
    init(
        trackId: Int64,
        trackTitle: String,
        source: String = "local",
        sourceTrackId: String = "",
        isFavorite: Bool = false,
        playbackController: PlaybackController? = nil,
        onAddToPlaylist: (() -> Void)? = nil,
        onShowAlbum: (() -> Void)? = nil,
        onShowArtist: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.trackId = trackId
        self.trackTitle = trackTitle
        self.source = source
        self.sourceTrackId = sourceTrackId
        self.isFavorite = isFavorite
        self.playbackController = playbackController
        self.onAddToPlaylist = onAddToPlaylist
        self.onShowAlbum = onShowAlbum
        self.onShowArtist = onShowArtist
        self.onDelete = onDelete
        self.onToggleFavorite = onToggleFavorite
    }
    
    @ViewBuilder
    func menuItems() -> some View {
        // Playback controls
        Group {
            Button {
                playbackController?.enqueueNext(trackIds: [trackId])
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Button {
                playbackController?.enqueueEnd(trackIds: [trackId])
            } label: {
                Label("Add to Queue", systemImage: "text.append")
            }
        }
        
        Divider()
        
        // Organization controls
        Group {
            if let onAddToPlaylist {
                Button {
                    onAddToPlaylist()
                } label: {
                    Label("Add to Playlist", systemImage: "plus.square.on.square")
                }
            }
            
            if let onToggleFavorite {
                Button {
                    onToggleFavorite()
                } label: {
                    if isFavorite {
                        Label("Remove from Favorites", systemImage: "heart.slash")
                    } else {
                        Label("Add to Favorites", systemImage: "heart")
                    }
                }
            }
        }
        
        Divider()
        
        // Navigation controls
        Group {
            if let onShowAlbum {
                Button {
                    onShowAlbum()
                } label: {
                    Label("Show Album", systemImage: "square.stack")
                }
            }
            
            if let onShowArtist {
                Button {
                    onShowArtist()
                } label: {
                    Label("Show Artist", systemImage: "music.mic")
                }
            }
        }
        
        Divider()
        
        // Destructive action
        if let onDelete {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Track", systemImage: "trash")
            }
        }
    }
}

/// Standard swipe actions for tracks
struct TrackSwipeActions {
    let trackId: Int64
    let playbackController: PlaybackController?
    let onDelete: (() -> Void)?
    let deleteLabel: String
    
    init(
        trackId: Int64,
        playbackController: PlaybackController? = nil,
        onDelete: (() -> Void)? = nil,
        deleteLabel: String = "Delete"
    ) {
        self.trackId = trackId
        self.playbackController = playbackController
        self.onDelete = onDelete
        self.deleteLabel = deleteLabel
    }
    
    @ViewBuilder
    func leadingActions() -> some View {
        Button {
            playbackController?.enqueueEnd(trackIds: [trackId])
        } label: {
            Label("Add to Queue", systemImage: "text.append")
        }
        .tint(.blue)
    }
    
    @ViewBuilder
    func trailingActions() -> some View {
        if let onDelete {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(deleteLabel, systemImage: "trash")
            }
        }
    }
}
