//
//  AirPlayButton.swift
//  mp3 Player
//
//  Created by GitHub Copilot on 25.01.2026.
//

import SwiftUI
import AVKit

struct AirPlayButton: View {
    var body: some View {
        AirPlayButtonRepresentable()
            .frame(width: 30, height: 30)
    }
}

private struct AirPlayButtonRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = .clear
        routePickerView.tintColor = .white
        routePickerView.activeTintColor = .systemBlue
        routePickerView.prioritizesVideoDevices = false
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // No updates needed
    }
}
