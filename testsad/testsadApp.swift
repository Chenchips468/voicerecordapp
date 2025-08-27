import SwiftUI

@main
struct TestsadApp: App {
    @StateObject private var speech = SpeechRecognizer()

    init() {
        // Make PhoneSession alive early and give it the speech engine.
        PhoneSession.shared.speechRecognizer = speech
    }

    var body: some Scene {
        WindowGroup {
            SwiftUIView()
                .environmentObject(speech) // optionally inject, or keep your @StateObject in the view
        }
    }
}
