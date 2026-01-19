import MediaPlayer
import SwiftUI
import UIKit

struct NowPlayingView: View {
    @Environment(\.playbackController) private var playbackController

    var body: some View {
        if let playbackController {
            NowPlayingContent(controller: playbackController)
        } else {
            ContentUnavailableView("Playback unavailable", systemImage: "music.note")
        }
    }
}

private struct NowPlayingContent: View {
    @ObservedObject var controller: PlaybackController
    @Environment(\.dismiss) private var dismiss
    @State private var isScrubbing = false
    @State private var scrubberValue = 0.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ArtworkImageView(
                        artworkUri: controller.currentItem?.artworkUri,
                        cornerRadius: 0,
                        contentMode: .fit
                    )
                        .frame(height: 240)

                    VStack(spacing: 4) {
                        Text(controller.currentItem?.title ?? "Not Playing")
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        if let artist = controller.currentItem?.artist {
                            Text(artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let album = controller.currentItem?.album {
                            Text(album)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { isScrubbing ? scrubberValue : controller.currentTime },
                                set: { scrubberValue = $0 }
                            ),
                            in: 0...max(controller.duration, 1),
                            onEditingChanged: { editing in
                                isScrubbing = editing
                                if editing {
                                    scrubberValue = controller.currentTime
                                } else {
                                    controller.seek(to: scrubberValue)
                                }
                            }
                        )

                        HStack {
                            Text(timeLabel(isScrubbing ? scrubberValue : controller.currentTime))
                            Spacer()
                            Text(timeLabel(controller.duration))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 32) {
                        Button {
                            controller.previous()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                        }

                        Button {
                            controller.togglePlayPause()
                        } label: {
                            Image(systemName: controller.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                        }

                        Button {
                            controller.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 8)

                    HStack(spacing: 24) {
                        Button {
                            controller.isShuffleEnabled.toggle()
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        .foregroundStyle(controller.isShuffleEnabled ? .primary : .secondary)

                        Button {
                            cycleRepeat()
                        } label: {
                            Label(repeatLabel, systemImage: repeatIcon)
                        }
                        .foregroundStyle(controller.repeatMode == .off ? .secondary : .primary)
                    }
                    .font(.footnote)

                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.secondary)
                        SystemVolumeView()
                            .frame(height: 28)
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(.secondary)
                    }

                    if let lyrics = controller.currentLyrics {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lyrics")
                                .font(.headline)
                            Text(lyrics)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Queue")
                            .font(.headline)
                        if controller.queueItems.isEmpty {
                            Text("Queue is empty")
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(controller.queueItems.enumerated()), id: \.offset) { index, item in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading) {
                                            Text(item.title)
                                            if let artist = item.artist {
                                                Text(artist)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if controller.currentItem?.id == item.id {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        Button {
                                            controller.removeFromQueue(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .contextMenu {
                                        Button("Move Up") {
                                            moveQueueItem(from: index, to: index - 1)
                                        }
                                        .disabled(index == 0)

                                        Button("Move Down") {
                                            moveQueueItem(from: index, to: index + 2)
                                        }
                                        .disabled(index >= controller.queueItems.count - 1)

                                        Button(role: .destructive) {
                                            controller.removeFromQueue(at: index)
                                        } label: {
                                            Text("Remove")
                                        }
                                    }
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationTitle("Now Playing")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .appScreen()
        .onAppear {
            scrubberValue = controller.currentTime
        }
    }

    private var repeatIcon: String {
        switch controller.repeatMode {
        case .off:
            return "repeat"
        case .one:
            return "repeat.1"
        case .all:
            return "repeat"
        }
    }

    private var repeatLabel: String {
        switch controller.repeatMode {
        case .off:
            return "Repeat Off"
        case .one:
            return "Repeat One"
        case .all:
            return "Repeat All"
        }
    }

    private func cycleRepeat() {
        switch controller.repeatMode {
        case .off:
            controller.repeatMode = .all
        case .all:
            controller.repeatMode = .one
        case .one:
            controller.repeatMode = .off
        }
    }

    private func timeLabel(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func moveQueueItem(from index: Int, to destination: Int) {
        guard destination >= 0, destination <= controller.queueItems.count else { return }
        controller.moveQueue(fromOffsets: IndexSet(integer: index), toOffset: destination)
    }
}

private struct SystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

#Preview {
    NowPlayingView()
}
