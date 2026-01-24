//
//  TimingIndicator.swift
//  mp3 Player
//
//  Created by Alexey Vorobyov on 13.12.2024.
//

import SwiftUI

struct TimingIndicator: View {
    let spacing: CGFloat
    @Environment(NowPlayingAdapter.self) var model
    @State var progress: Double = 0

    var body: some View {
        let range = 0.0 ... max(model.duration, 1.0)
        ElasticSlider(
            value: $progress,
            in: range,
            leadingLabel: {
                label(leadingLabelText)
            },
            trailingLabel: {
                label(trailingLabelText)
            }
        )
        .sliderStyle(.playbackProgress)
        .frame(height: 60)
        .transformEffect(.identity)
        .onAppear {
            progress = model.currentTime
        }
        .onChange(of: model.currentTime) { _, newTime in
            // Only update if not actively scrubbing
            if !isScrubbing {
                progress = newTime
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isScrubbing = true
                }
                .onEnded { _ in
                    isScrubbing = false
                    model.seek(to: progress)
                }
        )
    }
    
    @State private var isScrubbing: Bool = false
}

private extension TimingIndicator {
    func label(_ text: String) -> some View {
        Text(text)
            .font(.appFont.timingIndicator)
            .padding(.top, 11)
    }

    var leadingLabelText: String {
        progress.asTimeString(style: .positional)
    }

    var trailingLabelText: String {
        let range = 0.0 ... max(model.duration, 1.0)
        return ((range.upperBound - progress) * -1.0).asTimeString(style: .positional)
    }

    var palette: Palette.PlayerCard.Type {
        UIColor.palette.playerCard.self
    }
}

extension ElasticSliderConfig {
    static var playbackProgress: Self {
        Self(
            labelLocation: .bottom,
            maxStretch: 0,
            minimumTrackActiveColor: Color(Palette.PlayerCard.opaque),
            minimumTrackInactiveColor: Color(Palette.PlayerCard.translucent),
            maximumTrackColor: Color(Palette.PlayerCard.translucent),
            blendMode: .overlay,
            syncLabelsStyle: true
        )
    }
}


extension BinaryFloatingPoint {
    func asTimeString(style: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = style
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(self)) ?? ""
    }
}
