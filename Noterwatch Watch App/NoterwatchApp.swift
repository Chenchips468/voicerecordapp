//
//  NoterwatchApp.swift
//  Noterwatch Watch App
//
//  Created by William Chen on 8/26/25.
//

import SwiftUI
import WatchConnectivity

@main
struct Noterwatch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView2()
                .onOpenURL { url in
                    if url.scheme == "testsadapp", url.host == "startRecording" {
                        print("⌚️ Watch app opened via Shortcut to start recording")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            WatchRecorderManager.shared.shouldStartRecordingFromShortcut = true
                        }
                    }
                }
        }
    }
}
