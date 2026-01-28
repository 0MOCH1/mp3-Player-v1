//
//  NowPlayingBackground.swift
//  mp3 Player
//
//  Created by Alexey Vorobyov on 02.01.2025.
//

import SwiftUI

struct NowPlayingBackground: View {
    let colors: [Color]
    let expanded: Bool
    let isFullExpanded: Bool
    var canBeExpanded: Bool = true

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.thickMaterial)
            if canBeExpanded {
                ColorfulBackground(colors: colors)
                    .overlay(Color(UIColor(white: 0.4, alpha: 0.5)))
                    .opacity(expanded ? 1 : 0)
            }
        }
        .clipShape(.rect(cornerRadius: expanded ? 0 : 14))
        .frame(height: expanded ? nil : ViewConst.compactNowPlayingHeight)
        .ignoresSafeArea(.all)
        .shadow(
            color: .primary.opacity(colorScheme == .light ? 0.2 : 0),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

