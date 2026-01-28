//
//  ClosedRange+Extensions.swift
//  mp3 Player
//

import Foundation

extension ClosedRange where Bound: AdditiveArithmetic {
    var distance: Bound {
        upperBound - lowerBound
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
