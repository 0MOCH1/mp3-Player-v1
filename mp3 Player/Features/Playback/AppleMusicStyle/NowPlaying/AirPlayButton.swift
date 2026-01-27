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
    }
}

private struct AirPlayButtonRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = .clear
        routePickerView.tintColor = .white.withAlphaComponent(0.8)
        routePickerView.activeTintColor = .white
        routePickerView.prioritizesVideoDevices = false
        
        // ボタンのサイズを調整
        for subview in routePickerView.subviews {
            if let button = subview as? UIButton {
                button.contentMode = .scaleAspectFit
            }
        }
        
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // tintColor更新
        uiView.tintColor = .white.withAlphaComponent(0.8)
    }
}
