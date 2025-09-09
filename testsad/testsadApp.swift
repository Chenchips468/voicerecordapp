import SwiftUI

@main
struct TestsadApp: App {
    @StateObject private var phoneSession = PhoneSessionManager.shared
    @StateObject private var recorder = AudioRecorderManager.shared
    
    var body: some Scene {
        WindowGroup {
            ScrollView {
                VStack(alignment: .leading) {
                    PhoneRecordMp3()
                    m4atotext()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .environmentObject(phoneSession)
            }
            .onOpenURL { url in
                if url.scheme == "testsadapp", url.host == "startRecording" {
                    print("🚀 App opened via Shortcut to start recording")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        recorder.shouldStartRecordingFromShortcut = true
                    }
                }
            }
        }
    }
}
