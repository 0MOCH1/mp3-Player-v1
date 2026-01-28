//
//  UIScreen+DisplayCornerRadius.swift
//  mp3 Player
//
//  Adapted from ScreenCorners by Kyle Bashour
//  https://github.com/kylebshr/ScreenCorners
//

import UIKit

extension UIScreen {
    private static let cornerRadiusKey: String = {
        let components = ["Radius", "Corner", "display", "_"]
        return components.reversed().joined()
    }()

    /// The corner radius of the display. Uses a private property of `UIScreen`,
    /// and may report 0 if the API changes.
    var displayCornerRadius: CGFloat {
        guard let cornerRadius = self.value(forKey: Self.cornerRadiusKey) as? CGFloat else {
            // Fallback to a reasonable default if the private API changes
            return 39.0
        }
        return cornerRadius
    }
}
