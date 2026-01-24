//
//  PreviewBackground.swift
//  mp3 Player
//
//  Created by Alexey Vorobyov on 25.12.2024.
//

import SwiftUI

struct PreviewBackground: View {
    var body: some View {
        ColorfulBackground(
            colors: [
                UIColor(red: 0.85, green: 0.7, blue: 0.6, alpha: 1.0),
                UIColor(red: 0.15, green: 0.3, blue: 0.2, alpha: 1.0)
            ].map { Color($0) }
        )
        .overlay(Color(UIColor(white: 0.4, alpha: 0.5)))
        .ignoresSafeArea()
    }
}

