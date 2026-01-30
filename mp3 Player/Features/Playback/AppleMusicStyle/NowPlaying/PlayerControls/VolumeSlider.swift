//
//  VolumeSlider.swift
//  mp3 Player
//
//  Created by Alexey Vorobyov on 24.12.2024.
//

import SwiftUI
import AVFoundation
import MediaPlayer

public struct VolumeSlider: View {
    @Environment(NowPlayingAdapter.self) var model
    @State var volume: Double = 0.5
    @State var minVolumeAnimationTrigger: Bool = false
    @State var maxVolumeAnimationTrigger: Bool = false
    @State private var volumeView: MPVolumeView?
    @State private var volumeObservation: NSKeyValueObservation?
    let range = 0.0 ... 1

    public var body: some View {
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
        .font(.system(size: 14, weight: .bold))
        .onAppear {
            // Initialize with system volume
            updateVolume(Double(AVAudioSession.sharedInstance().outputVolume), animated: false)
            
            // Setup hidden MPVolumeView to suppress OS volume HUD
            setupVolumeView()
            observeSystemVolume()
        }
        .onDisappear {
            volumeObservation?.invalidate()
            volumeObservation = nil
        }
        .onChange(of: volume) { oldValue, newValue in
            // Update system volume via MPVolumeView slider
            if let volumeSlider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider {
                volumeSlider.value = Float(newValue)
            }
            
            if newValue == range.lowerBound {
                minVolumeAnimationTrigger.toggle()
            }
            if newValue == range.upperBound {
                maxVolumeAnimationTrigger.toggle()
            }
        }
        .frame(height: 50)
    }
    
    private func observeSystemVolume() {
        let session = AVAudioSession.sharedInstance()
        volumeObservation = session.observe(\.outputVolume, options: [.new]) { _, change in
            guard let newValue = change.newValue else { return }
            Task { @MainActor in
                updateVolume(Double(newValue), animated: true)
            }
        }
    }

    private func updateVolume(_ newValue: Double, animated: Bool) {
        let clamped = min(max(newValue, range.lowerBound), range.upperBound)
        guard abs(volume - clamped) > 0.001 else { return }
        if animated {
            withAnimation(.smooth(duration: 0.2)) {
                volume = clamped
            }
        } else {
            volume = clamped
        }
    }

    private func setupVolumeView() {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.showsVolumeSlider = true
        // Note: showsRouteButton is deprecated but AVRoutePickerView is not a direct replacement
        // for hiding the route button in MPVolumeView. Using KVC to avoid deprecation warning.
        // This is safe as the key has been stable since iOS 3.0.
        view.setValue(false, forKey: "showsRouteButton")
        view.isHidden = false
        view.alpha = 0.0001
        
        // Add to window to suppress system volume HUD
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(view)
            volumeView = view
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
