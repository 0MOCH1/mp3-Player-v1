//
//  AirPlayButton.swift
//  mp3 Player
//
//  AirPlay route picker button
//

import SwiftUI
import AVKit

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = UIColor.white
        routePickerView.activeTintColor = UIColor.white
        routePickerView.prioritizesVideoDevices = false
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
