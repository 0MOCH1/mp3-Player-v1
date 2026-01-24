//
//  mp3_PlayerApp.swift
//  mp3 Player
//
//  Created by Minato on 2026/01/19.
//

import SwiftUI

@main
struct mp3_PlayerApp: App {
    private let appDatabase: AppDatabase
    private let playbackController: PlaybackController
    private let appleMusicService: any AppleMusicService
    private let progressCenter = ProgressCenter()

    init() {
        do {
            appDatabase = try AppDatabase()
            playbackController = PlaybackController(appDatabase: appDatabase)
            appleMusicService = MusicKitAppleMusicService()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            OverlayableRootView {
                ContentView()
                    .environment(\.appDatabase, appDatabase)
                    .environment(\.playbackController, playbackController)
                    .environment(\.appleMusicService, appleMusicService)
                    .environment(\.progressCenter, progressCenter)
                    .environmentObject(playbackController)
                    .environmentObject(progressCenter)
            }
        }
    }
}
