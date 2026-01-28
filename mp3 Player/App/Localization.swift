import SwiftUI

/// Localized string keys for consistent string management across the app
enum L10n {
    // MARK: - Navigation
    enum Navigation {
        static let home = LocalizedStringKey("nav.home")
        static let library = LocalizedStringKey("nav.library")
        static let search = LocalizedStringKey("nav.search")
        static let settings = LocalizedStringKey("nav.settings")
    }
    
    // MARK: - Home
    enum Home {
        enum Section {
            static let recent = LocalizedStringKey("home.section.recent")
            static let recentPlays = LocalizedStringKey("home.section.recentPlays")
            static let topArtists = LocalizedStringKey("home.section.topArtists")
        }
        
        enum Empty {
            static let noRecentItems = LocalizedStringKey("home.empty.noRecentItems")
            static let noRecentPlays = LocalizedStringKey("home.empty.noRecentPlays")
            static let noTopArtists = LocalizedStringKey("home.empty.noTopArtists")
        }
    }
    
    // MARK: - Library
    enum Library {
        enum Section {
            static let `import` = LocalizedStringKey("library.section.import")
            static let nowPlaying = LocalizedStringKey("library.section.nowPlaying")
            static let browse = LocalizedStringKey("library.section.browse")
            static let missingFiles = LocalizedStringKey("library.section.missingFiles")
            static let library = LocalizedStringKey("library.section.library")
        }
        
        enum Import {
            static let mode = LocalizedStringKey("library.import.mode")
            static let deleteOriginal = LocalizedStringKey("library.import.deleteOriginal")
            static let files = LocalizedStringKey("library.import.files")
            static let folder = LocalizedStringKey("library.import.folder")
            static let importing = LocalizedStringKey("library.import.importing")
        }
        
        enum Browse {
            static let tracks = LocalizedStringKey("library.browse.tracks")
            static let albums = LocalizedStringKey("library.browse.albums")
            static let albumArtists = LocalizedStringKey("library.browse.albumArtists")
            static let artists = LocalizedStringKey("library.browse.artists")
            static let playlists = LocalizedStringKey("library.browse.playlists")
        }
        
        enum Stats {
            static func albums(_ count: Int) -> String {
                String(format: NSLocalizedString("library.stats.albums", comment: ""), count)
            }
            static func artists(_ count: Int) -> String {
                String(format: NSLocalizedString("library.stats.artists", comment: ""), count)
            }
            static func tracks(_ count: Int) -> String {
                String(format: NSLocalizedString("library.stats.tracks", comment: ""), count)
            }
            static func playlists(_ count: Int) -> String {
                String(format: NSLocalizedString("library.stats.playlists", comment: ""), count)
            }
        }
    }
    
    // MARK: - Search
    enum Search {
        enum Section {
            static let source = LocalizedStringKey("search.section.source")
            static let appleMusic = LocalizedStringKey("search.section.appleMusic")
            static let results = LocalizedStringKey("search.section.results")
        }
        
        static let scope = LocalizedStringKey("search.scope")
        
        enum Scope {
            static let local = LocalizedStringKey("search.scope.local")
            static let external = LocalizedStringKey("search.scope.external")
        }
        
        static let placeholder = LocalizedStringKey("search.placeholder")
        
        enum Empty {
            static let typeToSearch = LocalizedStringKey("search.empty.typeToSearch")
            static let typeToSearchAppleMusic = LocalizedStringKey("search.empty.typeToSearchAppleMusic")
            static let authRequired = LocalizedStringKey("search.empty.authRequired")
            static let noArtists = LocalizedStringKey("search.empty.noArtists")
            static let noAlbums = LocalizedStringKey("search.empty.noAlbums")
            static let noTracks = LocalizedStringKey("search.empty.noTracks")
            static let noPlaylists = LocalizedStringKey("search.empty.noPlaylists")
            static let noLyrics = LocalizedStringKey("search.empty.noLyrics")
        }
        
        enum Action {
            static let requestAccess = LocalizedStringKey("search.action.requestAccess")
            static let seeAllArtists = LocalizedStringKey("search.action.seeAllArtists")
            static let seeAllAlbums = LocalizedStringKey("search.action.seeAllAlbums")
            static let seeAllTracks = LocalizedStringKey("search.action.seeAllTracks")
            static let seeAllPlaylists = LocalizedStringKey("search.action.seeAllPlaylists")
            static let seeAllLyrics = LocalizedStringKey("search.action.seeAllLyrics")
        }
        
        enum Category {
            static let artists = LocalizedStringKey("search.category.artists")
            static let albums = LocalizedStringKey("search.category.albums")
            static let tracks = LocalizedStringKey("search.category.tracks")
            static let playlists = LocalizedStringKey("search.category.playlists")
            static let lyrics = LocalizedStringKey("search.category.lyrics")
        }
    }
    
    // MARK: - Context Menu
    enum Menu {
        static let playNext = LocalizedStringKey("menu.playNext")
        static let addToQueue = LocalizedStringKey("menu.addToQueue")
        static let addToPlaylist = LocalizedStringKey("menu.addToPlaylist")
        static let addToFavorites = LocalizedStringKey("menu.addToFavorites")
        static let removeFromFavorites = LocalizedStringKey("menu.removeFromFavorites")
        static let showAlbum = LocalizedStringKey("menu.showAlbum")
        static let showArtist = LocalizedStringKey("menu.showArtist")
        static let delete = LocalizedStringKey("menu.delete")
        static let deleteTrack = LocalizedStringKey("menu.deleteTrack")
        static let relink = LocalizedStringKey("menu.relink")
        static let remove = LocalizedStringKey("menu.remove")
    }
    
    // MARK: - Import
    enum ImportMode {
        static let reference = LocalizedStringKey("import.mode.reference")
        static let copy = LocalizedStringKey("import.mode.copy")
        static let copyThenDelete = LocalizedStringKey("import.mode.copyThenDelete")
    }
    
    enum ImportStatus {
        static func imported(_ count: Int) -> String {
            String(format: NSLocalizedString("import.status.imported", comment: ""), count)
        }
        static func relinked(_ count: Int) -> String {
            String(format: NSLocalizedString("import.status.relinked", comment: ""), count)
        }
        static func skipped(_ count: Int) -> String {
            String(format: NSLocalizedString("import.status.skipped", comment: ""), count)
        }
        static func failed(_ count: Int) -> String {
            String(format: NSLocalizedString("import.status.failed", comment: ""), count)
        }
    }
    
    enum ImportError {
        static let unavailable = LocalizedStringKey("import.error.unavailable")
        static func failed(_ error: String) -> String {
            String(format: NSLocalizedString("import.error.failed", comment: ""), error)
        }
        static let noFiles = LocalizedStringKey("import.error.noFiles")
        static let noFolder = LocalizedStringKey("import.error.noFolder")
    }
    
    // MARK: - Playback
    enum Playback {
        static let notPlaying = LocalizedStringKey("playback.notPlaying")
        static let queueEmpty = LocalizedStringKey("playback.queueEmpty")
        static let clearQueue = LocalizedStringKey("playback.clearQueue")
    }
    
    // MARK: - Common Actions
    enum Action {
        static let ok = LocalizedStringKey("action.ok")
        static let cancel = LocalizedStringKey("action.cancel")
        static let delete = LocalizedStringKey("action.delete")
        static let add = LocalizedStringKey("action.add")
        static let done = LocalizedStringKey("action.done")
        static let edit = LocalizedStringKey("action.edit")
        static let save = LocalizedStringKey("action.save")
    }
    
    // MARK: - Dialogs
    enum Dialog {
        enum DeleteTrack {
            static let title = LocalizedStringKey("dialog.deleteTrack.title")
            static let message = LocalizedStringKey("dialog.deleteTrack.message")
        }
        
        enum DeleteFailed {
            static let title = LocalizedStringKey("dialog.deleteFailed.title")
        }
        
        enum TrackOptions {
            static let title = LocalizedStringKey("dialog.trackOptions.title")
        }
    }
    
    // MARK: - Accessibility
    enum Accessibility {
        static let settings = LocalizedStringKey("accessibility.settings")
        static let nowPlaying = LocalizedStringKey("accessibility.nowPlaying")
        static let favorite = LocalizedStringKey("accessibility.favorite")
    }
    
    // MARK: - Missing Files
    enum Missing {
        static func relinkSuccess(_ title: String) -> String {
            String(format: NSLocalizedString("missing.relink.success", comment: ""), title)
        }
        static func relinkFailed(_ error: String) -> String {
            String(format: NSLocalizedString("missing.relink.failed", comment: ""), error)
        }
        static let relinkNoFile = LocalizedStringKey("missing.relink.noFile")
        static let relinkUnsupported = LocalizedStringKey("missing.relink.unsupported")
        static func deleteSuccess(_ title: String) -> String {
            String(format: NSLocalizedString("missing.delete.success", comment: ""), title)
        }
        static func deleteFailed(_ error: String) -> String {
            String(format: NSLocalizedString("missing.delete.failed", comment: ""), error)
        }
    }
}
