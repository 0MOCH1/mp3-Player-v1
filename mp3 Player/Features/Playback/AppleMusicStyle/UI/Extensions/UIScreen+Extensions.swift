//
//  UIScreen+Extensions.swift
//  mp3 Player
//

import UIKit

extension UIScreen {
    static var deviceCornerRadius: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            let screen = windowScene.screen
            return screen.value(forKey: "_displayCornerRadius") as? CGFloat ?? 0
        }
        return 0
    }

    static var hairlineWidth: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            let screen = windowScene.screen
            return 1 / screen.scale
        }
        return 1.0
    }
}
