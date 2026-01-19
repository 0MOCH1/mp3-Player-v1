import SwiftUI

private struct AppleMusicServiceKey: EnvironmentKey {
    static let defaultValue: (any AppleMusicService)? = nil
}

extension EnvironmentValues {
    var appleMusicService: (any AppleMusicService)? {
        get { self[AppleMusicServiceKey.self] }
        set { self[AppleMusicServiceKey.self] = newValue }
    }
}
