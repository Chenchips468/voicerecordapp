import SwiftUI
import WatchConnectivity
import AppIntents
import WatchKit

struct WatchContentView: View {
    @StateObject private var wc = WatchSession.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(wc.status).font(.caption).lineLimit(1)
                if wc.isOfflineMode {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }

            ScrollView {
                Text(wc.liveText.isEmpty ? " " : wc.liveText)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(wc.isRecordingUI ? "Stop" : "Start") {
                if wc.isRecordingUI {
                    wc.sendCommand("stop")
                } else {
                    print("got here")
                    wc.sendCommand("start")
                }
                wc.isRecordingUI.toggle()
            }
            .buttonStyle(.borderedProminent)
            // Remove the disabled modifier to allow recording in offline mode
        }
        .padding()
    }
}
/*
 struct StartRecordingIntentWatch: AppIntent {
 static var title: LocalizedStringResource = "Start Recording on Watch"
 
 static var description = IntentDescription("Starts recording on the watch.")
 
 static var openAppWhenRun: Bool = true
 
 func perform() throws -> some IntentResult {
 DispatchQueue.main.async {
 if !WatchSession.shared.isRecordingUI {
 WatchSession.shared.isRecordingUI = true
 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
 WatchSession.shared.sendCommand("start")
 print("⌚️ Simulated Start button press from Siri shortcut")
 }
 }
 }
 return .result()
 }
 }
 
 
 struct MyWatchShortcuts: AppShortcutsProvider {
 static var appShortcuts: [AppShortcut] {
 AppShortcut(intent: StartRecordingIntentWatch(), phrases: ["Start recording in \(.applicationName)"], shortTitle: "Start Recording", systemImageName: "mic.fill")
 }
 }
 */
