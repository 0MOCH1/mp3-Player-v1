//
//  VolumeSlider.swift
//  mp3 Player
//
//  Created by Alexey Vorobyov on 24.12.2024.
//

import SwiftUI
import AVFoundation

public struct VolumeSlider: View {
    @Environment(NowPlayingAdapter.self) var model
    @State var volume: Double = 0.5
    @State var minVolumeAnimationTrigger: Bool = false
    @State var maxVolumeAnimationTrigger: Bool = false
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
        .font(.system(size: 14))
        .onAppear {
            // Initialize with controller's volume
            volume = Double(model.controller.volume)
        }
        .onChange(of: volume) { oldValue, newValue in
            // Update controller volume
            model.controller.setVolume(Float(newValue))
            
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

