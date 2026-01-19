import AVFoundation
import Foundation

struct AudioMetadata {
    let title: String?
    let artist: String?
    let album: String?
    let albumArtist: String?
    let genre: String?
    let lyrics: String?
    let releaseYear: Int?
    let trackNumber: Int?
    let discNumber: Int?
    let artworkData: Data?
    let duration: Double?
}

protocol AudioMetadataReader {
    func read(from url: URL) async throws -> AudioMetadata
}

final class AVAssetMetadataReader: AudioMetadataReader {
    func read(from url: URL) async throws -> AudioMetadata {
        let asset = AVURLAsset(url: url)
        let commonMetadata = try await asset.load(.commonMetadata)
        let fullMetadata = try await asset.load(.metadata)
        let formats = (try? await asset.load(.availableMetadataFormats)) ?? []
        var formatMetadata: [AVMetadataItem] = []
        for format in formats {
            if let items = try? await asset.loadMetadata(for: format) {
                formatMetadata.append(contentsOf: items)
            }
        }
        let metadata = commonMetadata + fullMetadata + formatMetadata
        let duration = try await asset.load(.duration)

        let title = await metadataString(.commonKeyTitle, keySpace: .common, metadata: metadata)
        let artist = await metadataString(.commonKeyArtist, keySpace: .common, metadata: metadata)
        let album = await metadataString(.commonKeyAlbumName, keySpace: .common, metadata: metadata)
        let genre = await metadataStringForKeys(["genre", "TCON"], metadata: metadata)
        let albumArtist = await metadataString(.iTunesMetadataKeyAlbumArtist, keySpace: .iTunes, metadata: metadata)
        let primaryLyrics = await metadataString(.iTunesMetadataKeyLyrics, keySpace: .iTunes, metadata: metadata)
        let fallbackLyrics: String?
        if primaryLyrics == nil {
            fallbackLyrics = await metadataStringForKeys(
                ["lyrics", "LYRICS", "USLT", "unsynchronized_lyric"],
                metadata: metadata
            )
        } else {
            fallbackLyrics = nil
        }
        let lyrics = primaryLyrics ?? fallbackLyrics

        let releaseDate = await metadataString(.iTunesMetadataKeyReleaseDate, keySpace: .iTunes, metadata: metadata)
        let creationDate = await metadataString(.commonKeyCreationDate, keySpace: .common, metadata: metadata)
        let releaseYear = parseYear(releaseDate ?? creationDate)

        let primaryTrackNumber = await metadataInt(.iTunesMetadataKeyTrackNumber, keySpace: .iTunes, metadata: metadata)
        let trackNumber: Int?
        if let primaryTrackNumber {
            trackNumber = primaryTrackNumber
        } else {
            trackNumber = await metadataIntForKeys(["TRCK", "track", "track_number"], metadata: metadata)
        }

        let primaryDiscNumber = await metadataInt(.iTunesMetadataKeyDiscNumber, keySpace: .iTunes, metadata: metadata)
        let discNumber: Int?
        if let primaryDiscNumber {
            discNumber = primaryDiscNumber
        } else {
            discNumber = await metadataIntForKeys(["TPOS", "disc", "disc_number"], metadata: metadata)
        }

        let artworkData: Data?
        if let commonArtwork = await metadataData(.commonKeyArtwork, keySpace: .common, metadata: metadata) {
            artworkData = commonArtwork
        } else if let itunesArtwork = await metadataData(.iTunesMetadataKeyCoverArt, keySpace: .iTunes, metadata: metadata) {
            artworkData = itunesArtwork
        } else {
            artworkData = await metadataDataForKeys(["covr", "APIC", "artwork", "cover"], metadata: metadata)
        }

        let seconds = duration.isNumeric ? duration.seconds : nil

        return AudioMetadata(
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            lyrics: lyrics,
            releaseYear: releaseYear,
            trackNumber: trackNumber,
            discNumber: discNumber,
            artworkData: artworkData,
            duration: seconds
        )
    }

    private func metadataString(
        _ key: AVMetadataKey,
        keySpace: AVMetadataKeySpace,
        metadata: [AVMetadataItem]
    ) async -> String? {
        let items = AVMetadataItem.metadataItems(from: metadata, withKey: key, keySpace: keySpace)
        for item in items {
            if let string = await loadStringValue(from: item) {
                return string
            }
        }
        return nil
    }

    private func metadataStringForKeys(_ keys: [String], metadata: [AVMetadataItem]) async -> String? {
        for item in metadata {
            if let commonKey = item.commonKey?.rawValue, keys.contains(commonKey) {
                if let string = await loadStringValue(from: item) {
                    return string
                }
                continue
            }
            if let key = item.key as? AVMetadataKey, keys.contains(key.rawValue) {
                if let string = await loadStringValue(from: item) {
                    return string
                }
                continue
            }
            if let key = item.key as? String, keys.contains(key) {
                if let string = await loadStringValue(from: item) {
                    return string
                }
                continue
            }
        }
        return nil
    }

    private func metadataInt(
        _ key: AVMetadataKey,
        keySpace: AVMetadataKeySpace,
        metadata: [AVMetadataItem]
    ) async -> Int? {
        let items = AVMetadataItem.metadataItems(from: metadata, withKey: key, keySpace: keySpace)
        for item in items {
            if let value = await loadIntValue(from: item) {
                return value
            }
        }
        return nil
    }

    private func metadataIntForKeys(_ keys: [String], metadata: [AVMetadataItem]) async -> Int? {
        for item in metadata {
            if let commonKey = item.commonKey?.rawValue, keys.contains(commonKey) {
                if let value = await loadIntValue(from: item) {
                    return value
                }
                continue
            }
            if let key = item.key as? AVMetadataKey, keys.contains(key.rawValue) {
                if let value = await loadIntValue(from: item) {
                    return value
                }
                continue
            }
            if let key = item.key as? String, keys.contains(key) {
                if let value = await loadIntValue(from: item) {
                    return value
                }
                continue
            }
        }
        return nil
    }

    private func metadataData(
        _ key: AVMetadataKey,
        keySpace: AVMetadataKeySpace,
        metadata: [AVMetadataItem]
    ) async -> Data? {
        let items = AVMetadataItem.metadataItems(from: metadata, withKey: key, keySpace: keySpace)
        for item in items {
            if let data = await loadDataValue(from: item) {
                return data
            }
        }
        return nil
    }

    private func metadataDataForKeys(_ keys: [String], metadata: [AVMetadataItem]) async -> Data? {
        for item in metadata {
            if let commonKey = item.commonKey?.rawValue, keys.contains(commonKey) {
                if let data = await loadDataValue(from: item) {
                    return data
                }
                continue
            }
            if let key = item.key as? AVMetadataKey, keys.contains(key.rawValue) {
                if let data = await loadDataValue(from: item) {
                    return data
                }
                continue
            }
            if let key = item.key as? String, keys.contains(key) {
                if let data = await loadDataValue(from: item) {
                    return data
                }
                continue
            }
        }
        return nil
    }

    private func loadStringValue(from item: AVMetadataItem) async -> String? {
        do {
            let value: String? = try await item.load(.stringValue)
            guard let string = value, !string.isEmpty else { return nil }
            return string
        } catch {
            return nil
        }
    }

    private func loadDataValue(from item: AVMetadataItem) async -> Data? {
        do {
            let data: Data? = try await item.load(.dataValue)
            if let data, !data.isEmpty {
                return data
            }
        } catch {
            // Ignore load errors; fall back to direct value access below.
        }

        do {
            let value: Any? = try await item.load(.value)
            if let data = value as? Data {
                return data
            }
            if let data = value as? NSData {
                return data as Data
            }
        } catch {
            return nil
        }
        return nil
    }

    private func loadIntValue(from item: AVMetadataItem) async -> Int? {
        do {
            let number: NSNumber? = try await item.load(.numberValue)
            if let number {
                return number.intValue
            }
            let string: String? = try await item.load(.stringValue)
            return parseInt(string)
        } catch {
            return nil
        }
    }

    private func parseInt(_ value: String?) -> Int? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: "/")
        let first = parts.first ?? Substring(trimmed)
        return Int(first.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func parseYear(_ value: String?) -> Int? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return nil }
        let prefix = trimmed.prefix(4)
        return Int(prefix)
    }
}
