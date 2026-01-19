import Foundation
import MusicKit

enum AppleMusicAuthorizationStatus: String {
    case notDetermined
    case denied
    case restricted
    case authorized
    case unknown

    init(_ status: MusicAuthorization.Status) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .authorized:
            self = .authorized
        @unknown default:
            self = .unknown
        }
    }

    var canRequestAccess: Bool {
        self == .notDetermined
    }

    var isAuthorized: Bool {
        self == .authorized
    }
}

protocol AppleMusicService: AnyObject {
    func authorizationStatus() -> AppleMusicAuthorizationStatus
    func requestAuthorization() async -> AppleMusicAuthorizationStatus
}

@MainActor
final class MusicKitAppleMusicService: AppleMusicService {
    func authorizationStatus() -> AppleMusicAuthorizationStatus {
        AppleMusicAuthorizationStatus(MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> AppleMusicAuthorizationStatus {
        let status = await MusicAuthorization.request()
        return AppleMusicAuthorizationStatus(status)
    }
}
