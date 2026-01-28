import Foundation

/// Helper for performing track deletion with consistent behavior across views
struct TrackDeletionHelper {
    /// Deletes a track and handles common cleanup tasks
    /// - Parameters:
    ///   - target: The track to delete
    ///   - appDatabase: The app database instance
    ///   - playbackController: The playback controller (optional)
    ///   - onSuccess: Callback executed on successful deletion
    ///   - onError: Callback executed on error, receives error message
    static func deleteTrack(
        _ target: TrackDeleteTarget,
        appDatabase: AppDatabase?,
        playbackController: PlaybackController?,
        onSuccess: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        guard let appDatabase else { return }
        let deletionService = TrackDeletionService(appDatabase: appDatabase)
        Task {
            do {
                _ = try await deletionService.deleteTrack(trackId: target.id)
                await MainActor.run {
                    playbackController?.removeTrackFromQueue(trackId: target.id)
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    onError(error.localizedDescription)
                }
            }
        }
    }
}
