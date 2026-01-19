import SwiftUI

private struct ProgressCenterKey: EnvironmentKey {
    static let defaultValue: ProgressCenter? = nil
}

extension EnvironmentValues {
    var progressCenter: ProgressCenter? {
        get { self[ProgressCenterKey.self] }
        set { self[ProgressCenterKey.self] = newValue }
    }
}
