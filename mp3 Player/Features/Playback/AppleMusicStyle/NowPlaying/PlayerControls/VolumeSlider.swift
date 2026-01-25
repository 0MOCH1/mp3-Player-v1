//
//  VolumeSlider.swift
//  mp3 Player
//
//  Created by Alexey Vorobyov on 24.12.2024.
//

import SwiftUI
import MediaPlayer

/// System volume slider using MPVolumeView for device volume control
public struct VolumeSlider: UIViewRepresentable {
    
    public func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsVolumeSlider = true
        // Hide route button - we use separate AirPlayButton
        volumeView.setRouteButtonImage(UIImage(), for: .normal)
        
        // Style the slider to match the player design
        volumeView.tintColor = Palette.PlayerCard.opaque
        
        // Find and style the slider
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.minimumTrackTintColor = Palette.PlayerCard.opaque.withAlphaComponent(0.8)
            slider.maximumTrackTintColor = Palette.PlayerCard.translucent.withAlphaComponent(0.3)
            slider.thumbTintColor = Palette.PlayerCard.opaque
        }
        
        return volumeView
    }
    
    public func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

