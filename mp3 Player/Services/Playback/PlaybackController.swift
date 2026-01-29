import Accelerate
import AVFoundation
import Combine
import CoreGraphics
import Foundation
import GRDB
import MediaPlayer

@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var state: PlaybackState = .stopped
    @Published private(set) var currentItem: PlaybackItem?
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var repeatMode: RepeatMode = .off
    @Published var isShuffleEnabled = false
    @Published private(set) var queueItems: [PlaybackItem] = []
    @Published private(set) var volume: Float = 1.0
    @Published private(set) var currentLyrics: String?
    @Published private(set) var visualizerLevels: [CGFloat] = Array(repeating: 0, count: 5)

    private let appDatabase: AppDatabase
    private let player = AVPlayer()
    private let fileManager = FileManager.default
    private let queuePersistence: QueuePersistence
    private let positionWriter: PlaybackPositionWriter
    private let visualizerService: AudioVisualizerService
    private var timeObserver: Any?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var queue: [PlaybackItem] = []
    private var currentIndex: Int?
    private var isHandlingEnd = false
    private var isHandlingFailure = false
    private var shouldResumeAfterInterruption = false
    private var lastSavedPosition: Double = 0
    private var lastSavedTimestamp: TimeInterval = 0
    private var lastSavedKey: String?
    private let positionSaveInterval: Double = 5
    private var didRestoreQueue = false
    private var accessedURL: URL?
    private var lastPlaybackStateKey: String?

    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
        self.queuePersistence = QueuePersistence(dbPool: appDatabase.dbPool)
        self.positionWriter = PlaybackPositionWriter(dbPool: appDatabase.dbPool)
        self.visualizerService = AudioVisualizerService()
        self.visualizerService.setLevelsHandler { [weak self] levels in
            Task { @MainActor in
                self?.visualizerLevels = levels
            }
        }
        player.volume = volume
        configureAudioSession()
        installTimeObserver()
        installPlayerObservers()
        installRemoteCommands()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlay),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemPlaybackStalled),
            name: .AVPlayerItemPlaybackStalled,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(artworkRepairDidComplete),
            name: .artworkRepairDidComplete,
            object: nil
        )

        Task { @MainActor in
            await restoreQueueIfNeeded()
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeControlObservation?.invalidate()
        itemStatusObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func artworkRepairDidComplete() {
        refreshQueueArtwork()
    }

    func setQueue(trackIds: [Int64], startAt index: Int = 0, playImmediately: Bool = true, sourceName: String? = nil, sourceType: QueueSourceType = .unknown) {
        Task {
            var items = await fetchPlaybackItemsAsync(trackIds: trackIds)
            // ソース情報を設定
            if sourceName != nil || sourceType != .unknown {
                items = items.map { item in
                    var mutableItem = item
                    mutableItem.queueSourceName = sourceName
                    mutableItem.queueSourceType = sourceType
                    return mutableItem
                }
            }
            queue = items
            queueItems = items
            persistQueueSnapshot(items)
            if items.isEmpty {
                stop()
                return
            }
            let safeIndex = min(max(index, 0), items.count - 1)
            await setCurrentIndex(safeIndex, playImmediately: playImmediately, recordHistory: playImmediately)
        }
    }

    func enqueueNext(trackIds: [Int64]) {
        Task {
            let items = await fetchPlaybackItemsAsync(trackIds: trackIds)
            guard !items.isEmpty else { return }
            guard let currentIndex, !queue.isEmpty else {
                setQueue(trackIds: trackIds, startAt: 0, playImmediately: true)
                return
            }

            let insertIndex = min(currentIndex + 1, queue.count)
            queue.insert(contentsOf: items, at: insertIndex)
            queueItems = queue
            persistQueueInsert(items, at: insertIndex)
        }
    }

    func enqueueEnd(trackIds: [Int64]) {
        Task {
            let items = await fetchPlaybackItemsAsync(trackIds: trackIds)
            guard !items.isEmpty else { return }
            guard !queue.isEmpty else {
                setQueue(trackIds: trackIds, startAt: 0, playImmediately: true)
                return
            }

            let insertIndex = queue.count
            queue.append(contentsOf: items)
            queueItems = queue
            persistQueueInsert(items, at: insertIndex)
        }
    }

    func moveQueue(fromOffsets: IndexSet, toOffset: Int) {
        guard !queue.isEmpty else { return }
        let updatedQueue = movedItems(queue, fromOffsets: fromOffsets, toOffset: toOffset)
        let updatedIndices = movedItems(Array(queue.indices), fromOffsets: fromOffsets, toOffset: toOffset)
        let newCurrentIndex = currentIndex.flatMap { updatedIndices.firstIndex(of: $0) }

        queue = updatedQueue
        queueItems = updatedQueue
        currentIndex = newCurrentIndex
        persistQueueSnapshot(updatedQueue)

        if let newCurrentIndex, newCurrentIndex < queue.count {
            persistPlaybackState(for: queue[newCurrentIndex], index: newCurrentIndex)
        }
    }

    func playFromHistory(source: TrackSource, sourceTrackId: String) {
        guard let item = fetchPlaybackItem(source: source, sourceTrackId: sourceTrackId) else { return }

        if queue.isEmpty {
            setQueue(trackIds: [item.id], startAt: 0, playImmediately: true)
            return
        }

        let index = currentIndex ?? 0
        let safeIndex = min(max(index, 0), queue.count - 1)
        queue[safeIndex] = item
        queueItems = queue
        persistQueueReplace(at: safeIndex, with: item)

        Task { await setCurrentIndex(safeIndex, playImmediately: true, recordHistory: true) }
    }
    
    /// 履歴からトラックIDで再生を開始 (v8仕様対応)
    func playFromHistoryById(_ trackId: Int64) {
        guard let item = fetchPlaybackItemByTrackId(trackId) else { return }
        
        if queue.isEmpty {
            setQueue(trackIds: [item.id], startAt: 0, playImmediately: true)
            return
        }
        
        let index = currentIndex ?? 0
        let safeIndex = min(max(index, 0), queue.count - 1)
        queue[safeIndex] = item
        queueItems = queue
        persistQueueReplace(at: safeIndex, with: item)
        
        Task { await setCurrentIndex(safeIndex, playImmediately: true, recordHistory: true) }
    }

    func refreshQueueArtwork() {
        guard !queue.isEmpty || currentItem != nil else { return }
        Task {
            let uniqueIds = Array(Set(queue.map { $0.id }))
            let updatedItems = uniqueIds.isEmpty ? [] : await fetchPlaybackItemsAsync(trackIds: uniqueIds)
            var updatedById: [Int64: PlaybackItem] = [:]
            for item in updatedItems {
                updatedById[item.id] = item
            }

            if !queue.isEmpty {
                let refreshedQueue = queue.map { item in
                    updatedById[item.id] ?? item
                }
                queue = refreshedQueue
                queueItems = refreshedQueue
            }

            if let currentItem, let updated = updatedById[currentItem.id] {
                self.currentItem = updated
            }
        }
    }

    func play() {
        if currentItem == nil {
            guard !queue.isEmpty else { return }
            let index = currentIndex ?? 0
            Task { await setCurrentIndex(index, playImmediately: true, recordHistory: true) }
            return
        }
        if player.currentItem == nil {
            let index = currentIndex ?? 0
            Task { await setCurrentIndex(index, playImmediately: true, recordHistory: true) }
            return
        }
        player.play()
        updateState(.playing)
    }

    func pause() {
        player.pause()
        persistPositionIfNeeded(force: true)
        updateState(.paused)
    }

    func clearQueue() {
        queue.removeAll()
        queueItems = []
        persistQueueSnapshot([])
        stop()
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0, index < queue.count else { return }
        let wasCurrent = (index == currentIndex)
        queue.remove(at: index)
        queueItems = queue

        if queue.isEmpty {
            persistQueueSnapshot([])
            stop()
            return
        }

        if let currentIndex {
            if wasCurrent {
                let nextIndex = min(index, queue.count - 1)
                Task { await setCurrentIndex(nextIndex, playImmediately: true, recordHistory: true) }
            } else if index < currentIndex {
                let adjustedIndex = max(0, currentIndex - 1)
                self.currentIndex = adjustedIndex
                if adjustedIndex < queue.count {
                    let item = queue[adjustedIndex]
                    persistPlaybackState(for: item, index: adjustedIndex)
                }
            }
        }

        persistQueueRemove(at: index)
    }

    func removeTrackFromQueue(trackId: Int64) {
        guard !queue.isEmpty else { return }
        let indices = queue.indices.filter { queue[$0].id == trackId }
        guard !indices.isEmpty else { return }

        let current = currentIndex ?? 0
        let removedBefore = indices.filter { $0 < current }.count
        let currentWasRemoved = currentIndex.map { indices.contains($0) } ?? false

        queue.removeAll { $0.id == trackId }
        queueItems = queue

        if queue.isEmpty {
            persistQueueSnapshot([])
            stop()
            return
        }

        let newIndex = max(0, current - removedBefore)
        currentIndex = min(newIndex, queue.count - 1)

        if currentWasRemoved, let currentIndex {
            let playImmediately = state == .playing
            Task { await setCurrentIndex(currentIndex, playImmediately: playImmediately, recordHistory: false) }
        } else if let currentIndex {
            persistPlaybackState(for: queue[currentIndex], index: currentIndex)
        }

        persistQueueSnapshot(queue)
    }

    func togglePlayPause() {
        switch state {
        case .playing:
            pause()
        case .paused, .stopped, .buffering:
            play()
        }
    }

    func setVolume(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        volume = clamped
        player.volume = clamped
    }

    func next() {
        guard !queue.isEmpty else { return }
        if isShuffleEnabled, let nextIndex = randomNextIndex() {
            Task { await setCurrentIndex(nextIndex, playImmediately: true, recordHistory: true) }
            return
        }

        guard let currentIndex else { return }
        let nextIndex = currentIndex + 1
        if nextIndex < queue.count {
            Task { await setCurrentIndex(nextIndex, playImmediately: true, recordHistory: true) }
        } else if repeatMode == .all {
            Task { await setCurrentIndex(0, playImmediately: true, recordHistory: true) }
        } else {
            stop()
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 4 {
            seek(to: 0)
            return
        }
        guard let currentIndex else { return }
        let prevIndex = currentIndex - 1
        if prevIndex >= 0 {
            Task { await setCurrentIndex(prevIndex, playImmediately: true, recordHistory: true) }
        } else if repeatMode == .all {
            Task { await setCurrentIndex(queue.count - 1, playImmediately: true, recordHistory: true) }
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: target)
        currentTime = seconds
        updateNowPlayingTime()
    }

    private func stop() {
        persistPositionIfNeeded(force: true)
        endFileAccess()
        player.pause()
        player.replaceCurrentItem(with: nil)
        visualizerService.beginDecayToZero()
        state = .stopped
        currentItem = nil
        currentLyrics = nil
        currentIndex = nil
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func updateState(_ newState: PlaybackState) {
        state = newState
        updateNowPlayingInfo()
    }

    private func installTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            Task { @MainActor in
                self.currentTime = seconds
                self.updateNowPlayingTime()
                self.persistPositionIfNeeded(force: false)
            }
        }
    }

    private func installPlayerObservers() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleTimeControlStatus(player.timeControlStatus)
            }
        }
    }

    private func observePlayerItemStatus(_ item: AVPlayerItem) {
        itemStatusObservation?.invalidate()
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            guard let self else { return }
            guard observedItem.status == .failed else { return }
            Task { @MainActor in
                self.handlePlaybackFailure()
            }
        }
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        guard currentItem != nil else { return }
        switch status {
        case .playing:
            updateState(.playing)
        case .paused:
            if state != .stopped {
                updateState(.paused)
            }
        case .waitingToPlayAtSpecifiedRate:
            updateState(.buffering)
        @unknown default:
            break
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            // Best effort. Playback can still work without explicit configuration.
        }
    }

    private func installRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
    }

    @objc private func playerItemDidEnd(_ notification: Notification) {
        guard !isHandlingEnd else { return }
        isHandlingEnd = true
        defer { isHandlingEnd = false }

        if repeatMode == .one {
            seek(to: 0)
            play()
            return
        }

        if let item = currentItem {
            persistPosition(for: item, seconds: 0, force: true)
        }
        next()
    }

    @objc private func playerItemFailedToPlay(_ notification: Notification) {
        guard let failedItem = notification.object as? AVPlayerItem,
              failedItem == player.currentItem else { return }
        handlePlaybackFailure()
    }

    @objc private func playerItemPlaybackStalled(_ notification: Notification) {
        guard let stalledItem = notification.object as? AVPlayerItem,
              stalledItem == player.currentItem else { return }
        updateState(.buffering)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if state == .buffering {
                player.play()
            }
        }
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            shouldResumeAfterInterruption = (state == .playing)
            pause()
        case .ended:
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume), shouldResumeAfterInterruption {
                play()
            }
            shouldResumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        if reason == .oldDeviceUnavailable {
            pause()
        }
    }

    @objc private func handleMediaServicesReset(_ notification: Notification) {
        configureAudioSession()
        if state == .playing {
            player.play()
        }
    }

    private func handlePlaybackFailure() {
        guard !isHandlingFailure else { return }
        isHandlingFailure = true
        defer { isHandlingFailure = false }

        guard let failedIndex = currentIndex else {
            stop()
            return
        }
        if let item = currentItem {
            persistPosition(for: item, seconds: currentTime, force: true)
            if let reason = missingReasonIfNeeded(for: item) {
                markMissing(for: item, reason: reason)
            }
        }
        endFileAccess()

        if let nextIndex = nextPlayableIndex(after: failedIndex) {
            Task { await setCurrentIndex(nextIndex, playImmediately: true, recordHistory: true) }
        } else {
            stop()
        }
    }

    private func missingReasonIfNeeded(for item: PlaybackItem) -> MissingReason? {
        guard item.source == .local else { return nil }
        switch resolveFileAccess(for: item) {
        case .missing(let reason):
            return reason
        case .available(let url):
            return fileManager.fileExists(atPath: url.path) ? nil : .notFound
        }
    }

    private func updateNowPlayingInfo() {
        guard let item = currentItem else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.artist ?? "",
            MPMediaItemPropertyAlbumTitle: item.album ?? "",
        ]

        if let duration = item.duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        } else if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        
        // アートワークを設定（AirPlayポップアップに表示されるため）
        // ローカルファイルのみ同期で読み込み、リモートリソースは非同期で読み込み
        if let artworkUri = item.artworkUri,
           let artworkURL = URL(string: artworkUri) {
            if artworkURL.isFileURL {
                // ローカルファイルは同期で読み込み
                if let imageData = try? Data(contentsOf: artworkURL),
                   let image = UIImage(data: imageData) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    info[MPMediaItemPropertyArtwork] = artwork
                }
            } else {
                // リモートリソースは非同期で読み込み
                loadArtworkAsync(from: artworkURL)
            }
        }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = (state == .playing) ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func loadArtworkAsync(from url: URL) {
        Task.detached(priority: .userInitiated) {
            guard let imageData = try? Data(contentsOf: url),
                  let image = UIImage(data: imageData) else { return }
            
            await MainActor.run {
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }

    private func updateNowPlayingTime() {
        guard currentItem != nil else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = (state == .playing) ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func randomNextIndex() -> Int? {
        guard queue.count > 1 else { return nil }
        let current = currentIndex ?? 0
        var next = Int.random(in: 0..<queue.count)
        if next == current {
            next = (next + 1) % queue.count
        }
        return next
    }

    private func setCurrentIndex(_ index: Int, playImmediately: Bool, recordHistory: Bool) async {
        guard index >= 0, index < queue.count else { return }
        if let previous = currentItem {
            persistPosition(for: previous, seconds: currentTime, force: true)
        }

        currentIndex = index
        let item = queue[index]
        currentItem = item
        loadLyrics(for: item)
        currentTime = 0
        duration = item.duration ?? 0

        let access = resolveFileAccess(for: item)
        let resolvedURL: URL
        switch access {
        case .available(let url):
            resolvedURL = url
            guard beginFileAccess(url) else {
                handleMissingItem(item, failedIndex: index, reason: .notFound)
                return
            }
        case .missing(let reason):
            handleMissingItem(item, failedIndex: index, reason: reason)
            return
        }
        clearMissingFlagIfNeeded(for: item)

        let playerItem = AVPlayerItem(url: resolvedURL)
        observePlayerItemStatus(playerItem)
        player.replaceCurrentItem(with: playerItem)
        if let audioMix = await visualizerService.makeAudioMix(for: playerItem) {
            playerItem.audioMix = audioMix
        }

        if item.duration == nil {
            if let assetDuration = try? await playerItem.asset.load(.duration) {
                let seconds = assetDuration.seconds
                if seconds.isFinite {
                    duration = seconds
                }
            }
        }

        let resumePosition = fetchResumePosition(for: item)
        let normalizedResume = normalizedResumePosition(resumePosition, duration: duration)
        if normalizedResume > 0 {
            let target = CMTime(seconds: normalizedResume, preferredTimescale: 600)
            _ = await player.seek(to: target)
            currentTime = normalizedResume
        }

        persistPlaybackState(for: item, index: index)

        if recordHistory {
            recordPlaybackStart(item)
        }
        updateNowPlayingInfo()

        if playImmediately {
            play()
        }
    }

    private enum FileAccessOutcome {
        case available(URL)
        case missing(MissingReason)
    }

    private func resolveFileAccess(for item: PlaybackItem) -> FileAccessOutcome {
        if let data = fetchBookmarkData(for: item.id) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), url.isFileURL {
                return .available(url)
            }
            return .missing(.permission)
        }

        guard let fileUri = item.fileUri,
              let url = URL(string: fileUri),
              url.isFileURL else {
            return .missing(.invalidUri)
        }

        if isInAppSandbox(url) {
            return .available(url)
        }
        return .missing(.permission)
    }

    private func fetchBookmarkData(for trackId: Int64) -> Data? {
        (try? appDatabase.dbPool.read { db -> Data? in
            try Data.fetchOne(
                db,
                sql: """
                SELECT bookmark_data
                FROM import_records
                WHERE track_id = ?
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                arguments: [trackId]
            )
        }) ?? nil
    }

    private func loadLyrics(for item: PlaybackItem) {
        let content = (try? appDatabase.dbPool.read { db -> String? in
            try String.fetchOne(
                db,
                sql: """
                SELECT content
                FROM lyrics
                WHERE source = ? AND source_track_id = ?
                ORDER BY CASE provider WHEN ? THEN 0 ELSE 1 END, provider
                LIMIT 1
                """,
                arguments: [item.source, item.sourceTrackId, LyricsProvider.embedded.rawValue]
            )
        }) ?? nil
        let trimmed = content?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentLyrics = (trimmed?.isEmpty == false) ? trimmed : nil
    }

    private func isInAppSandbox(_ url: URL) -> Bool {
        let fileManager = fileManager
        let directories: [URL] = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        ].compactMap { $0 }

        return directories.contains { directory in
            url.path.hasPrefix(directory.path)
        }
    }

    private func beginFileAccess(_ url: URL) -> Bool {
        endFileAccess()
        let accessed = url.startAccessingSecurityScopedResource()
        let exists = fileManager.fileExists(atPath: url.path)
        if accessed {
            if exists {
                accessedURL = url
            } else {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return exists
    }

    private func endFileAccess() {
        if let url = accessedURL {
            url.stopAccessingSecurityScopedResource()
            accessedURL = nil
        }
    }

    private func handleMissingItem(_ item: PlaybackItem, failedIndex: Int, reason: MissingReason) {
        markMissing(for: item, reason: reason)
        endFileAccess()
        if let nextIndex = nextPlayableIndex(after: failedIndex) {
            Task { await setCurrentIndex(nextIndex, playImmediately: true, recordHistory: true) }
        } else {
            stop()
        }
    }

    private func nextPlayableIndex(after index: Int) -> Int? {
        guard !queue.isEmpty else { return nil }
        if queue.count == 1 {
            return nil
        }

        let candidateIndices: [Int]
        if isShuffleEnabled {
            var indices = Array(queue.indices)
            indices.removeAll { $0 == index }
            indices.shuffle()
            candidateIndices = indices
        } else {
            var indices: [Int] = []
            if index + 1 < queue.count {
                indices.append(contentsOf: (index + 1)..<queue.count)
            }
            if repeatMode == .all, index > 0 {
                indices.append(contentsOf: 0..<index)
            }
            candidateIndices = indices
        }

        for candidate in candidateIndices {
            if isLikelyPlayable(queue[candidate]) {
                return candidate
            }
        }

        return nil
    }

    private func isLikelyPlayable(_ item: PlaybackItem) -> Bool {
        if item.source != .local {
            return true
        }
        switch resolveFileAccess(for: item) {
        case .available(let url):
            return fileManager.fileExists(atPath: url.path)
        case .missing:
            return false
        }
    }

    private func markMissing(for item: PlaybackItem, reason: MissingReason) {
        guard item.source == .local else { return }
        let updatedAt = Int64(Date().timeIntervalSince1970)
        try? appDatabase.dbPool.write { db in
            try db.execute(
                sql: """
                UPDATE tracks
                SET is_missing = 1,
                    missing_reason = ?,
                    updated_at = ?
                WHERE source = ? AND source_track_id = ?
                """,
                arguments: [reason.rawValue, updatedAt, item.source, item.sourceTrackId]
            )
        }
    }

    private func clearMissingFlagIfNeeded(for item: PlaybackItem) {
        guard item.source == .local else { return }
        let updatedAt = Int64(Date().timeIntervalSince1970)
        try? appDatabase.dbPool.write { db in
            try db.execute(
                sql: """
                UPDATE tracks
                SET is_missing = 0,
                    missing_reason = NULL,
                    updated_at = ?
                WHERE source = ? AND source_track_id = ?
                """,
                arguments: [updatedAt, item.source, item.sourceTrackId]
            )
        }
    }

    private func movedItems<T>(_ items: [T], fromOffsets: IndexSet, toOffset: Int) -> [T] {
        guard !fromOffsets.isEmpty else { return items }
        var updated = items
        let moving = fromOffsets.sorted().map { updated[$0] }
        for index in fromOffsets.sorted(by: >) {
            updated.remove(at: index)
        }
        let removedBefore = fromOffsets.filter { $0 < toOffset }.count
        let destination = max(0, min(updated.count, toOffset - removedBefore))
        updated.insert(contentsOf: moving, at: destination)
        return updated
    }

    private func recordPlaybackStart(_ item: PlaybackItem) {
        let now = Int64(Date().timeIntervalSince1970)
        let day = DateUtils.yyyymmdd(Date())
        Task {
            try? await appDatabase.dbPool.write { db in
                let history = HistoryEntryRecord(
                    id: nil,
                    source: item.source,
                    sourceTrackId: item.sourceTrackId,
                    playedAt: now,
                    position: 0
                )
                try history.insert(db)

                try db.execute(
                    sql: """
                    DELETE FROM history_entries
                    WHERE id IN (
                        SELECT id
                        FROM history_entries
                        ORDER BY played_at DESC
                        LIMIT -1 OFFSET ?
                    )
                    """,
                    arguments: [100]
                )

                if let artistId = item.artistId {
                    try db.execute(
                        sql: """
                        INSERT INTO listening_stats (artist_id, day, play_count)
                        VALUES (?, ?, 1)
                        ON CONFLICT(artist_id, day)
                        DO UPDATE SET play_count = play_count + 1
                        """,
                        arguments: [artistId, day]
                    )
                }
            }
        }
    }

    private func fetchPlaybackItems(trackIds: [Int64]) -> [PlaybackItem] {
        Self.fetchPlaybackItems(dbPool: appDatabase.dbPool, trackIds: trackIds)
    }

    private func fetchPlaybackItemsAsync(trackIds: [Int64]) async -> [PlaybackItem] {
        guard !trackIds.isEmpty else { return [] }
        let dbPool = appDatabase.dbPool
        return await Task.detached(priority: .userInitiated) {
            Self.fetchPlaybackItems(dbPool: dbPool, trackIds: trackIds)
        }.value
    }

    nonisolated private static func fetchPlaybackItems(
        dbPool: DatabasePool,
        trackIds: [Int64]
    ) -> [PlaybackItem] {
        guard !trackIds.isEmpty else { return [] }
        let batchSize = 500
        var byId: [Int64: PlaybackItem] = [:]
        var start = 0

        while start < trackIds.count {
            let end = min(start + batchSize, trackIds.count)
            let batch = Array(trackIds[start..<end])
            let rows = (try? dbPool.read { db -> [Row] in
                let placeholders = batch.map { _ in "?" }.joined(separator: ",")
                return try Row.fetchAll(
                    db,
                    sql: """
                    SELECT
                        t.id AS id,
                        t.source AS source,
                        t.source_track_id AS source_track_id,
                        t.file_uri AS file_uri,
                        COALESCE(ta.file_uri, aa.file_uri) AS artwork_uri,
                        COALESCE(mo.title, t.title) AS title,
                        t.duration AS duration,
                        t.artist_id AS artist_id,
                        COALESCE(mo.artist_name, a.name) AS artist_name,
                        COALESCE(mo.album_name, al.name) AS album_name
                    FROM tracks t
                    LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                    LEFT JOIN artists a ON a.id = t.artist_id
                    LEFT JOIN albums al ON al.id = t.album_id
                    LEFT JOIN artworks ta ON ta.id = t.artwork_id
                    LEFT JOIN artworks aa ON aa.id = t.album_artwork_id
                    WHERE t.id IN (\(placeholders))
                    """,
                    arguments: StatementArguments(batch)
                )
            }) ?? []

            for row in rows {
                guard let id = row["id"] as Int64? else { continue }
                let sourceRaw = row["source"] as String? ?? TrackSource.local.rawValue
                let source = TrackSource(rawValue: sourceRaw) ?? .local
                let item = PlaybackItem(
                    id: id,
                    source: source,
                    sourceTrackId: row["source_track_id"] as String? ?? "",
                    fileUri: row["file_uri"] as String?,
                    artworkUri: row["artwork_uri"] as String?,
                    title: row["title"] as String? ?? "Unknown Title",
                    artist: row["artist_name"] as String?,
                    album: row["album_name"] as String?,
                    duration: row["duration"] as Double?,
                    artistId: row["artist_id"] as Int64?
                )
                byId[id] = item
            }

            start = end
        }

        return trackIds.compactMap { byId[$0] }
    }

    private func fetchPlaybackItem(source: TrackSource, sourceTrackId: String) -> PlaybackItem? {
        let row = (try? appDatabase.dbPool.read { db -> Row? in
            return try Row.fetchOne(
                db,
                sql: """
                SELECT
                    t.id AS id,
                    t.source AS source,
                    t.source_track_id AS source_track_id,
                    t.file_uri AS file_uri,
                    COALESCE(ta.file_uri, aa.file_uri) AS artwork_uri,
                    COALESCE(mo.title, t.title) AS title,
                    t.duration AS duration,
                    t.artist_id AS artist_id,
                    COALESCE(mo.artist_name, a.name) AS artist_name,
                    COALESCE(mo.album_name, al.name) AS album_name
                FROM tracks t
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists a ON a.id = t.artist_id
                LEFT JOIN albums al ON al.id = t.album_id
                LEFT JOIN artworks ta ON ta.id = t.artwork_id
                LEFT JOIN artworks aa ON aa.id = t.album_artwork_id
                WHERE t.source = ? AND t.source_track_id = ?
                """,
                arguments: [source, sourceTrackId]
            )
        }) ?? nil

        guard let row, let id = row["id"] as Int64? else { return nil }
        let sourceRaw = row["source"] as String? ?? TrackSource.local.rawValue
        let resolvedSource = TrackSource(rawValue: sourceRaw) ?? .local
        return PlaybackItem(
            id: id,
            source: resolvedSource,
            sourceTrackId: row["source_track_id"] as String? ?? "",
            fileUri: row["file_uri"] as String?,
            artworkUri: row["artwork_uri"] as String?,
            title: row["title"] as String? ?? "Unknown Title",
            artist: row["artist_name"] as String?,
            album: row["album_name"] as String?,
            duration: row["duration"] as Double?,
            artistId: row["artist_id"] as Int64?
        )
    }
    
    /// トラックIDからPlaybackItemを取得 (v8仕様対応)
    private func fetchPlaybackItemByTrackId(_ trackId: Int64) -> PlaybackItem? {
        let items = fetchPlaybackItems(trackIds: [trackId])
        return items.first
    }

    private func restoreQueueIfNeeded() async {
        guard !didRestoreQueue else { return }
        didRestoreQueue = true

        let rows = (try? appDatabase.dbPool.read { db -> [Row] in
            return try Row.fetchAll(
                db,
                sql: """
                SELECT
                    q.ord AS ord,
                    t.id AS id,
                    t.source AS source,
                    t.source_track_id AS source_track_id,
                    t.file_uri AS file_uri,
                    COALESCE(ta.file_uri, aa.file_uri) AS artwork_uri,
                    COALESCE(mo.title, t.title) AS title,
                    t.duration AS duration,
                    t.artist_id AS artist_id,
                    COALESCE(mo.artist_name, a.name) AS artist_name,
                    COALESCE(mo.album_name, al.name) AS album_name
                FROM queue_items q
                LEFT JOIN tracks t
                    ON t.source = q.source AND t.source_track_id = q.source_track_id
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists a ON a.id = t.artist_id
                LEFT JOIN albums al ON al.id = t.album_id
                LEFT JOIN artworks ta ON ta.id = t.artwork_id
                LEFT JOIN artworks aa ON aa.id = t.album_artwork_id
                ORDER BY q.ord
                """
            )
        }) ?? []

        var restored: [PlaybackItem] = []
        for row in rows {
            guard let id = row["id"] as Int64? else { continue }
            let sourceRaw = row["source"] as String? ?? TrackSource.local.rawValue
            let source = TrackSource(rawValue: sourceRaw) ?? .local
            let item = PlaybackItem(
                id: id,
                source: source,
                sourceTrackId: row["source_track_id"] as String? ?? "",
                fileUri: row["file_uri"] as String?,
                artworkUri: row["artwork_uri"] as String?,
                title: row["title"] as String? ?? "Unknown Title",
                artist: row["artist_name"] as String?,
                album: row["album_name"] as String?,
                duration: row["duration"] as Double?,
                artistId: row["artist_id"] as Int64?
            )
            restored.append(item)
        }

        let hadMissingEntries = restored.count != rows.count
        if restored.isEmpty {
            if !rows.isEmpty {
                persistQueueSnapshot([])
            }
            return
        }
        if hadMissingEntries {
            persistQueueSnapshot(restored)
        }
        queue = restored
        queueItems = restored

        let stateRecord = try? appDatabase.repositories.playbackState.fetch()
        let preferredIndex: Int
        if let stateRecord {
            if let matchIndex = restored.firstIndex(where: { item in
                item.source == stateRecord.source && item.sourceTrackId == stateRecord.sourceTrackId
            }) {
                preferredIndex = matchIndex
            } else if stateRecord.queueIndex >= 0, stateRecord.queueIndex < restored.count {
                preferredIndex = stateRecord.queueIndex
            } else {
                preferredIndex = 0
            }
        } else {
            preferredIndex = 0
        }

        currentIndex = preferredIndex
        currentItem = restored[preferredIndex]
        duration = restored[preferredIndex].duration ?? 0
        if hadMissingEntries {
            persistPlaybackState(for: restored[preferredIndex], index: preferredIndex)
        }
        updateNowPlayingInfo()
    }

    private func persistQueueSnapshot(_ items: [PlaybackItem]) {
        let items = items
        Task {
            await queuePersistence.replaceAll(items)
        }
    }

    private func persistQueueInsert(_ items: [PlaybackItem], at index: Int) {
        let items = items
        guard !items.isEmpty else { return }
        Task {
            await queuePersistence.insert(items, at: index)
        }
    }

    private func persistQueueReplace(at index: Int, with item: PlaybackItem) {
        Task {
            await queuePersistence.replace(at: index, with: item)
        }
    }

    private func persistQueueRemove(at index: Int) {
        Task {
            await queuePersistence.remove(at: index)
        }
    }

    private func persistPlaybackState(for item: PlaybackItem, index: Int) {
        let key = "\(item.source.rawValue)|\(item.sourceTrackId)|\(index)"
        guard key != lastPlaybackStateKey else { return }
        lastPlaybackStateKey = key

        let updatedAt = Int64(Date().timeIntervalSince1970)
        _ = try? appDatabase.repositories.playbackState.upsert(
            source: item.source,
            sourceTrackId: item.sourceTrackId,
            queueIndex: index,
            updatedAt: updatedAt
        )
    }

    private func fetchResumePosition(for item: PlaybackItem) -> Double {
        let record = try? appDatabase.repositories.playbackPositions.fetchPosition(
            source: item.source,
            sourceTrackId: item.sourceTrackId
        )
        return record?.position ?? 0
    }

    private func normalizedResumePosition(_ position: Double, duration: Double) -> Double {
        guard position > 0 else { return 0 }
        guard duration > 0 else { return position }
        if position >= duration - 2 {
            return 0
        }
        return min(position, duration)
    }

    private func persistPositionIfNeeded(force: Bool) {
        guard let item = currentItem else { return }
        persistPosition(for: item, seconds: currentTime, force: force)
    }

    private func persistPosition(for item: PlaybackItem, seconds: Double, force: Bool) {
        let key = "\(item.source.rawValue)|\(item.sourceTrackId)"
        let now = Date().timeIntervalSince1970

        if !force {
            let timeDelta = now - lastSavedTimestamp
            let positionDelta = abs(seconds - lastSavedPosition)
            if key == lastSavedKey, timeDelta < positionSaveInterval, positionDelta < positionSaveInterval {
                return
            }
        }

        lastSavedKey = key
        lastSavedTimestamp = now
        lastSavedPosition = seconds

        let updatedAt = Int64(now)
        let source = item.source
        let sourceTrackId = item.sourceTrackId
        let position = max(0, seconds)
        Task {
            await positionWriter.upsert(
                source: source,
                sourceTrackId: sourceTrackId,
                position: position,
                updatedAt: updatedAt
            )
        }
    }
    
    // MARK: - History
    
    /// 最近再生した履歴を取得
    func getRecentHistory(limit: Int = 20) async -> [(id: Int64, title: String, artist: String?, artworkUri: String?, playedAt: Date)] {
        let dbPool = appDatabase.dbPool
        let rows = (try? await dbPool.read { db -> [Row] in
            try Row.fetchAll(
                db,
                sql: """
                SELECT
                    h.id AS history_id,
                    h.played_at AS played_at,
                    t.id AS track_id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.artist_name, a.name) AS artist_name,
                    COALESCE(ta.file_uri, aa.file_uri) AS artwork_uri
                FROM history_entries h
                JOIN tracks t ON t.source = h.source AND t.source_track_id = h.source_track_id
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists a ON a.id = t.artist_id
                LEFT JOIN artworks ta ON ta.id = t.artwork_id
                LEFT JOIN artworks aa ON aa.id = t.album_artwork_id
                ORDER BY h.played_at DESC
                LIMIT ?
                """,
                arguments: [limit]
            )
        }) ?? []
        
        return rows.compactMap { row -> (id: Int64, title: String, artist: String?, artworkUri: String?, playedAt: Date)? in
            guard let historyId = row["history_id"] as Int64?,
                  let playedAtTimestamp = row["played_at"] as Int64? else {
                return nil
            }
            let title = row["title"] as String? ?? "Unknown Title"
            let artist = row["artist_name"] as String?
            let artworkUri = row["artwork_uri"] as String?
            let playedAt = Date(timeIntervalSince1970: TimeInterval(playedAtTimestamp))
            return (id: historyId, title: title, artist: artist, artworkUri: artworkUri, playedAt: playedAt)
        }
    }
}

private actor QueuePersistence {
    private let dbPool: DatabasePool

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    func replaceAll(_ items: [PlaybackItem]) {
        let now = Int64(Date().timeIntervalSince1970)
        do {
            try dbPool.write { db in
                _ = try QueueItemRecord.deleteAll(db)
                if items.isEmpty {
                    try db.execute(sql: "DELETE FROM playback_state")
                    return
                }
                for (index, item) in items.enumerated() {
                    let record = QueueItemRecord(
                        id: nil,
                        source: item.source,
                        sourceTrackId: item.sourceTrackId,
                        ord: index,
                        addedAt: now
                    )
                    try record.insert(db)
                }
            }
        } catch {
            // Best effort; queue persistence can fail without blocking playback.
        }
    }

    func insert(_ items: [PlaybackItem], at index: Int) {
        guard !items.isEmpty else { return }
        let now = Int64(Date().timeIntervalSince1970)
        do {
            try dbPool.write { db in
                try db.execute(
                    sql: "UPDATE queue_items SET ord = ord + ? WHERE ord >= ?",
                    arguments: [items.count, index]
                )
                for (offset, item) in items.enumerated() {
                    let record = QueueItemRecord(
                        id: nil,
                        source: item.source,
                        sourceTrackId: item.sourceTrackId,
                        ord: index + offset,
                        addedAt: now
                    )
                    try record.insert(db)
                }
            }
        } catch {
            // Best effort; queue persistence can fail without blocking playback.
        }
    }

    func remove(at index: Int) {
        do {
            try dbPool.write { db in
                try db.execute(
                    sql: "DELETE FROM queue_items WHERE ord = ?",
                    arguments: [index]
                )
                try db.execute(
                    sql: "UPDATE queue_items SET ord = ord - 1 WHERE ord > ?",
                    arguments: [index]
                )
            }
        } catch {
            // Best effort; queue persistence can fail without blocking playback.
        }
    }

    func replace(at index: Int, with item: PlaybackItem) {
        do {
            try dbPool.write { db in
                try db.execute(
                    sql: """
                    UPDATE queue_items
                    SET source = ?, source_track_id = ?
                    WHERE ord = ?
                    """,
                    arguments: [item.source, item.sourceTrackId, index]
                )
            }
        } catch {
            // Best effort; queue persistence can fail without blocking playback.
        }
    }
}

// MARK: - Audio Visualizer

private final class AudioVisualizerService {
    private static let bandEdges: [Float] = [40, 120, 350, 900, 3500, 12000]
    private let minDb: Float = -80
    private let maxDb: Float = 0
    private let gamma: Float = 0.5
    private let minVisible: Float = 0.03
    private let softClipK: Float = 1.4
    private let attackTime: Float = 0.08
    private let decayTime: Float = 0.5

    private var levels: [CGFloat] = Array(repeating: 0, count: 5)
    private var sampleRate: Float = 44100
    private var channelCount: Int = 2
    private var isFloat: Bool = true
    private var isNonInterleaved: Bool = false
    private var fftSetup: FFTSetup?
    private var fftSize: Int = 1024
    private var window: [Float] = []
    private var decayTimer: DispatchSourceTimer?
    private var levelsHandler: (([CGFloat]) -> Void)?

    func setLevelsHandler(_ handler: @escaping ([CGFloat]) -> Void) {
        levelsHandler = handler
    }

    func makeAudioMix(for item: AVPlayerItem) async -> AVAudioMix? {
        let tracks = (try? await item.asset.load(.tracks)) ?? []
        let audioTracks = tracks.filter { $0.mediaType == .audio }
        guard !audioTracks.isEmpty else { return nil }

        guard let tap = createTap() else { return nil }
        let mix = AVMutableAudioMix()
        mix.inputParameters = audioTracks.map { track in
            let params = AVMutableAudioMixInputParameters(track: track)
            params.audioTapProcessor = tap
            return params
        }
        return mix
    }

    func beginDecayToZero() {
        decayTimer?.cancel()
        decayTimer = nil
        guard levels.contains(where: { $0 > 0 }) else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0 / 30.0)
        timer.setEventHandler { [weak self] in
            self?.applyDecayStep()
        }
        decayTimer = timer
        timer.resume()
    }

    private func applyDecayStep() {
        let dt = Float(1.0 / 30.0)
        let releaseCoeff = exp(-dt / decayTime)
        var updated = levels
        var didChange = false
        for index in 0..<updated.count {
            let current = Float(updated[index])
            let next = releaseCoeff * current
            let clipped = next < 0.001 ? 0 : next
            if clipped != current {
                didChange = true
            }
            updated[index] = CGFloat(clipped)
        }
        levels = updated
        levelsHandler?(updated)
        if !didChange {
            decayTimer?.cancel()
            decayTimer = nil
        }
    }

    private func createTap() -> MTAudioProcessingTap? {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )
        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap)
        if status != noErr {
            return nil
        }
        return tap
    }

    private func prepare(with format: AudioStreamBasicDescription, maxFrames: Int) {
        sampleRate = Float(format.mSampleRate)
        channelCount = Int(format.mChannelsPerFrame)
        isFloat = (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        isNonInterleaved = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0

        let maxSize = max(256, min(4096, maxFrames.nextPowerOfTwo))
        fftSize = maxSize
        if let existing = fftSetup {
            vDSP_destroy_fftsetup(existing)
        }
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    private func unprepare() {
        decayTimer?.cancel()
        decayTimer = nil
        if let existing = fftSetup {
            vDSP_destroy_fftsetup(existing)
        }
        fftSetup = nil
    }

    private func process(tap: MTAudioProcessingTap, numberFrames: Int, bufferList: UnsafeMutablePointer<AudioBufferList>) {
        guard numberFrames > 0 else { return }
        decayTimer?.cancel()
        decayTimer = nil
        var flags = MTAudioProcessingTapFlags(rawValue: 0)
        var framesOut = CMItemCount(numberFrames)
        let status = MTAudioProcessingTapGetSourceAudio(tap, CMItemCount(numberFrames), bufferList, &flags, nil, &framesOut)
        if status != noErr { return }

        let frameCount = min(Int(framesOut), numberFrames)
        guard frameCount > 1 else { return }
        let candidateSize = min(fftSize, frameCount)
        let effectiveSize = candidateSize.previousPowerOfTwo
        guard effectiveSize > 1 else { return }
        let monoSamples = extractMonoSamples(from: bufferList, frameCount: effectiveSize)
        guard monoSamples.count >= effectiveSize else { return }
        guard let fftSetup else { return }

        var windowed = monoSamples
        vDSP_vmul(windowed, 1, window, 1, &windowed, 1, vDSP_Length(effectiveSize))

        var real = [Float](repeating: 0, count: effectiveSize / 2)
        var imag = [Float](repeating: 0, count: effectiveSize / 2)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)

        windowed.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: effectiveSize / 2) { complexBuffer in
                vDSP_ctoz(complexBuffer, 2, &splitComplex, 1, vDSP_Length(effectiveSize / 2))
            }
        }
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(effectiveSize))), FFTDirection(FFT_FORWARD))

        var magnitudes = [Float](repeating: 0, count: effectiveSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(effectiveSize / 2))

        let bandLevels = aggregateBands(magnitudes: magnitudes, fftSize: effectiveSize)
        let smoothed = smoothLevels(bandLevels, frameCount: frameCount)
        levels = smoothed
        levelsHandler?(smoothed)
    }

    private func extractMonoSamples(from bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) -> [Float] {
        let audioBufferList = bufferList.pointee
        let channels = max(1, channelCount)
        var mono = [Float](repeating: 0, count: frameCount)

        if isNonInterleaved {
            let bufferCount = Int(audioBufferList.mNumberBuffers)
            for bufferIndex in 0..<min(bufferCount, channels) {
                let buffer = audioBufferList.mBuffers.advanced(by: bufferIndex).pointee
                guard let data = buffer.mData else { continue }
                if isFloat {
                    let samples = data.assumingMemoryBound(to: Float.self)
                    for frame in 0..<frameCount {
                        mono[frame] += samples[frame] / Float(channels)
                    }
                } else {
                    let samples = data.assumingMemoryBound(to: Int16.self)
                    for frame in 0..<frameCount {
                        mono[frame] += Float(samples[frame]) / (32768.0 * Float(channels))
                    }
                }
            }
        } else {
            let buffer = audioBufferList.mBuffers
            guard let data = buffer.mData else { return mono }
            if isFloat {
                let samples = data.assumingMemoryBound(to: Float.self)
                for frame in 0..<frameCount {
                    var sum: Float = 0
                    let baseIndex = frame * channels
                    for channel in 0..<channels {
                        sum += samples[baseIndex + channel]
                    }
                    mono[frame] = sum / Float(channels)
                }
            } else {
                let samples = data.assumingMemoryBound(to: Int16.self)
                for frame in 0..<frameCount {
                    var sum: Float = 0
                    let baseIndex = frame * channels
                    for channel in 0..<channels {
                        sum += Float(samples[baseIndex + channel]) / 32768.0
                    }
                    mono[frame] = sum / Float(channels)
                }
            }
        }
        return mono
    }

    private func aggregateBands(magnitudes: [Float], fftSize: Int) -> [Float] {
        let binHz = sampleRate / Float(fftSize)
        var bandValues: [Float] = []
        for index in 0..<AudioVisualizerService.bandEdges.count - 1 {
            let startHz = AudioVisualizerService.bandEdges[index]
            let endHz = AudioVisualizerService.bandEdges[index + 1]
            let startBin = max(1, Int(startHz / binHz))
            let endBin = min(magnitudes.count - 1, Int(endHz / binHz))
            if startBin >= endBin {
                bandValues.append(0)
                continue
            }
            var sum: Float = 0
            for bin in startBin..<endBin {
                sum += magnitudes[bin]
            }
            let avg = sum / Float(endBin - startBin)
            let db = 10 * log10(max(avg, 1e-10))
            let normalized = max(0, min(1, (db - minDb) / (maxDb - minDb)))
            let gammaAdjusted = pow(normalized, gamma)
            let visible = max(gammaAdjusted, minVisible)
            let softClipped = visible / (1 + softClipK * visible)
            bandValues.append(softClipped)
        }
        return bandValues
    }

    private func smoothLevels(_ newLevels: [Float], frameCount: Int) -> [CGFloat] {
        let dt = Float(frameCount) / max(sampleRate, 1)
        let attackCoeff = exp(-dt / attackTime)
        let releaseCoeff = exp(-dt / decayTime)
        var updated: [CGFloat] = []
        for (index, value) in newLevels.enumerated() {
            let current = index < levels.count ? Float(levels[index]) : 0
            let coeff = value > current ? attackCoeff : releaseCoeff
            let smoothed = coeff * current + (1 - coeff) * value
            updated.append(CGFloat(smoothed))
        }
        return updated
    }
}

private struct TapStorage {
    let service: AudioVisualizerService
}

private func tapInit(tap: MTAudioProcessingTap, clientInfo: UnsafeMutableRawPointer?, tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>) {
    guard let clientInfo else { return }
    let service = Unmanaged<AudioVisualizerService>.fromOpaque(clientInfo).takeUnretainedValue()
    let storage = UnsafeMutablePointer<TapStorage>.allocate(capacity: 1)
    storage.initialize(to: TapStorage(service: service))
    tapStorageOut.pointee = UnsafeMutableRawPointer(storage)
}

private func tapFinalize(tap: MTAudioProcessingTap) {
    if let storagePointer = MTAudioProcessingTapGetStorage(tap) {
        let storage = storagePointer.assumingMemoryBound(to: TapStorage.self)
        storage.deinitialize(count: 1)
        storage.deallocate()
    }
}

private func tapPrepare(tap: MTAudioProcessingTap, maxFrames: CMItemCount, processingFormat: UnsafePointer<AudioStreamBasicDescription>) {
    guard let storagePointer = MTAudioProcessingTapGetStorage(tap) else { return }
    let storage = storagePointer.assumingMemoryBound(to: TapStorage.self)
    storage.pointee.service.prepare(with: processingFormat.pointee, maxFrames: Int(maxFrames))
}

private func tapUnprepare(tap: MTAudioProcessingTap) {
    guard let storagePointer = MTAudioProcessingTapGetStorage(tap) else { return }
    let storage = storagePointer.assumingMemoryBound(to: TapStorage.self)
    storage.pointee.service.unprepare()
}

private func tapProcess(
    tap: MTAudioProcessingTap,
    numberFrames: CMItemCount,
    bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    numberFramesOut.pointee = numberFrames
    guard let storagePointer = MTAudioProcessingTapGetStorage(tap) else { return }
    let storage = storagePointer.assumingMemoryBound(to: TapStorage.self)
    storage.pointee.service.process(tap: tap, numberFrames: Int(numberFrames), bufferList: bufferListInOut)
}

private extension Int {
    var nextPowerOfTwo: Int {
        guard self > 0 else { return 1 }
        var value = 1
        while value < self {
            value <<= 1
        }
        return value
    }

    var previousPowerOfTwo: Int {
        guard self > 0 else { return 1 }
        var value = 1
        while value <= self {
            value <<= 1
        }
        return max(1, value >> 1)
    }
}

private actor PlaybackPositionWriter {
    private let dbPool: DatabasePool

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    func upsert(source: TrackSource, sourceTrackId: String, position: Double, updatedAt: Int64) {
        do {
            try dbPool.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO playback_positions (source, source_track_id, position, updated_at)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(source, source_track_id)
                    DO UPDATE SET position = excluded.position, updated_at = excluded.updated_at
                    """,
                    arguments: [source, sourceTrackId, position, updatedAt]
                )
            }
        } catch {
            // Best effort; playback position save can fail without blocking playback.
        }
    }
}

#if DEBUG
extension PlaybackController {
    @MainActor
    static func preview() -> PlaybackController {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mp3-player-preview-\(UUID().uuidString)", isDirectory: true)
        let appDatabase = try! AppDatabase(directory: directory)
        let controller = PlaybackController(appDatabase: appDatabase)

        let items: [PlaybackItem] = [
            PlaybackItem(
                id: 1,
                source: .local,
                sourceTrackId: "preview-1",
                fileUri: nil,
                artworkUri: nil,
                title: "Midnight Drive",
                artist: "Astra",
                album: "Neon Nights",
                duration: 245,
                artistId: nil
            ),
            PlaybackItem(
                id: 2,
                source: .local,
                sourceTrackId: "preview-2",
                fileUri: nil,
                artworkUri: nil,
                title: "Ocean Echoes",
                artist: "Blue Harbor",
                album: "Neon Nights",
                duration: 203,
                artistId: nil
            ),
            PlaybackItem(
                id: 3,
                source: .local,
                sourceTrackId: "preview-3",
                fileUri: nil,
                artworkUri: nil,
                title: "Afterglow",
                artist: "Astra",
                album: "City Lights",
                duration: 262,
                artistId: nil
            )
        ]

        controller.queue = items
        controller.queueItems = items
        controller.currentIndex = 0
        controller.currentItem = items.first
        controller.duration = items.first?.duration ?? 0
        controller.currentTime = 92
        controller.state = .playing
        controller.repeatMode = .all
        controller.isShuffleEnabled = true
        controller.currentLyrics = """
        Hold on to the night, it never really fades
        Streetlights in the distance paint the sound of waves
        """

        return controller
    }
}
#endif
