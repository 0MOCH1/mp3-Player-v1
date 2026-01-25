//
//  VolumeSlider.swift
//  mp3 Player
//
//  Created by Alexey Vorobyov on 24.12.2024.
//

import SwiftUI
import MediaPlayer
import AVFoundation

public struct VolumeSlider: View {
    @Environment(NowPlayingAdapter.self) var model
    @State var volume: Double = 0.5
    @State var minVolumeAnimationTrigger: Bool = false
    @State var maxVolumeAnimationTrigger: Bool = false
    let range = 0.0 ... 1

    public var body: some View {
        ZStack {
            // Hidden MPVolumeView for system volume control
            SystemVolumeSlider(volume: $volume)
                .frame(width: 0, height: 0)
                .opacity(0)
            
            // Custom visual slider synced with system volume
            ElasticSlider(
                value: $volume,
                in: range,
                leadingLabel: {
                    Image(systemName: "speaker.fill")
                        .padding(.trailing, 10)
                        .symbolEffect(.bounce, value: minVolumeAnimationTrigger)
                },
                trailingLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                        .padding(.leading, 10)
                        .symbolEffect(.bounce, value: maxVolumeAnimationTrigger)
                }
            )
            .sliderStyle(.volume)
            .font(.system(size: 14))
            .onChange(of: volume) { oldValue, newValue in
                if newValue == range.lowerBound {
                    minVolumeAnimationTrigger.toggle()
                }
                if newValue == range.upperBound {
                    maxVolumeAnimationTrigger.toggle()
                }
            }
            .frame(height: 50)
        }
    }
}

/// Hidden system volume view that syncs with the custom slider
struct SystemVolumeSlider: UIViewRepresentable {
    @Binding var volume: Double
    
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsVolumeSlider = true
        volumeView.setRouteButtonImage(UIImage(), for: .normal)
        volumeView.isHidden = true
        
        // Get the slider and observe its value
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.addTarget(context.coordinator, action: #selector(Coordinator.sliderValueChanged(_:)), for: .valueChanged)
            // Initialize with current system volume
            DispatchQueue.main.async {
                volume = Double(slider.value)
            }
        }
        
        return volumeView
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        // Update the system slider when our binding changes
        if let slider = uiView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            if abs(Double(slider.value) - volume) > 0.01 {
                slider.value = Float(volume)
                // Trigger the volume change
                slider.sendActions(for: .valueChanged)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(volume: $volume)
    }
    
    class Coordinator: NSObject {
        var volume: Binding<Double>
        
        init(volume: Binding<Double>) {
            self.volume = volume
        }
        
        @objc func sliderValueChanged(_ slider: UISlider) {
            DispatchQueue.main.async {
                self.volume.wrappedValue = Double(slider.value)
            }
        }
    }
}

extension ElasticSliderConfig {
    static var volume: Self {
        Self(
            labelLocation: .side,
            maxStretch: 10,
            minimumTrackActiveColor: Color(Palette.PlayerCard.opaque),
            minimumTrackInactiveColor: Color(Palette.PlayerCard.translucent),
            maximumTrackColor: Color(Palette.PlayerCard.translucent),
            blendMode: .overlay,
            syncLabelsStyle: true
        )
    }
}

