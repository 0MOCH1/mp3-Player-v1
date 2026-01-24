//
//  Time.swift
//  mp3 Player
//

import Foundation

public func delay(_ delay: Double, closure: @escaping @Sendable () -> Void) {
    let when = DispatchTime.now() + delay
    DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
}
