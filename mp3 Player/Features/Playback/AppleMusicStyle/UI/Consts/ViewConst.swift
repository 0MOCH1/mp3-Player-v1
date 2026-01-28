//
//  ViewConst.swift
//  mp3 Player
//

import Foundation
import SwiftUI
import UIKit

enum ViewConst {}

@MainActor
extension ViewConst {
    static let playerCardPaddings: CGFloat = 32
    static let screenPaddings: CGFloat = 20
    static let tabbarHeight: CGFloat = safeAreaInsets.bottom + 92
    static let compactNowPlayingHeight: CGFloat = 56
    
    // Grip (Layer0) constants
    static let gripWidth: CGFloat = 64  // 80ptから20%短縮
    static let gripHeight: CGFloat = 5
    static let gripTopPadding: CGFloat = 8
    /// Grip用のスペース（GripはLayer0で描画されるため、ContentPanelではスペースのみ確保）
    static var gripSpaceHeight: CGFloat {
        gripTopPadding + gripHeight + gripTopPadding // topPadding + gripHeight + bottomPadding
    }
    
    // ContentPanel spacing
    static let contentTopPadding: CGFloat = 8
    
    // CompactTrackInfo position offset (10pt up from default)
    static let compactTrackInfoTopOffset: CGFloat = -10
    
    // History Gate threshold for Queue panel snap behavior
    static let historyGateThreshold: CGFloat = 80
    
    // PlayerControls spacing (iPhone 16 Pro基準)
    static let bottomToFooterPadding: CGFloat = 3  // safeArea.bottom に追加
    static let footerToVolumeSpacing: CGFloat = 10  // 25pt - 15pt
    static let volumeToPlayerButtonsSpacing: CGFloat = 30  // SeekBar→PlayerButtonsと同値
    static let playerButtonsToSeekBarSpacing: CGFloat = 30
    static let seekBarToTrackInfoSpacing: CGFloat = 30
    
    // QueueControls button sizing
    static let queueControlsVerticalPadding: CGFloat = 13  // 8 + 5
    static let queueControlsHorizontalPadding: CGFloat = 36  // 16 + 20
    
    // Animation duration (fast, commercial quality)
    static let animationDuration: Double = 0.2
    
    // Queue artwork corner radius
    static let queueArtworkCornerRadius: CGFloat = 4
    
    static var safeAreaInsets: EdgeInsets {
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return EdgeInsets(window.safeAreaInsets)
        } else {
            return EdgeInsets(UIEdgeInsets.zero)
        }
    }
}

extension EdgeInsets {
    init(_ insets: UIEdgeInsets) {
        self.init(
            top: insets.top,
            leading: insets.left,
            bottom: insets.bottom,
            trailing: insets.right
        )
    }
}
