//
//  AnimationExtensions.swift
//  mp3 Player
//

import SwiftUI

extension Animation {
    static var playerExpandAnimation: Animation {
        .smooth(duration: playerExpandAnimationDuration, extraBounce: 0.0)
    }
    
    static var playerExpandAnimationDuration: Double {
        0.35
    }
}
