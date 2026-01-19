import SwiftUI

private struct PlaybackControllerKey: EnvironmentKey {
    static let defaultValue: PlaybackController? = nil
}

extension EnvironmentValues {
    var playbackController: PlaybackController? {
        get { self[PlaybackControllerKey.self] }
        set { self[PlaybackControllerKey.self] = newValue }
    }
}
