import SwiftUI
import WatchConnectivity
import AppIntents
import WatchKit
import AVFoundation

class WatchRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording: Bool = false
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    func startRecording() {
        let fileName = "recording-\(UUID().uuidString).m4a"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            recordingURL = fileURL
            isRecording = true
        } catch {
            print("Failed to start recording: \(error)")
            isRecording = false
        }
    }

    func stopRecordingAndSend() {
        audioRecorder?.stop()
        isRecording = false
        guard let fileURL = recordingURL else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            WatchSession.shared.sendRecording(fileURL: fileURL)
        }
        recordingURL = nil
    }
}

struct WatchContentView2: View {
    @StateObject private var wc = WatchSession.shared
    @StateObject private var recorder = WatchRecorderManager()

    var body: some View {
        VStack(spacing: 8) {
            Text(wc.status).font(.caption).lineLimit(1)

            ScrollView {
                Text(wc.liveText.isEmpty ? " " : wc.liveText)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(recorder.isRecording ? "Stop" : "Start") {
                if recorder.isRecording {
                    recorder.stopRecordingAndSend()
                    wc.isRecordingUI = false
                } else {
                    recorder.startRecording()
                    wc.isRecordingUI = true
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!wc.isReachable)
        }
        .padding()
    }
}

struct StartRecordingIntentWatch: AppIntent {
    static var title: LocalizedStringResource = "Start Recording on Watch"

    static var description = IntentDescription("Starts recording on the watch.")

    static var openAppWhenRun: Bool = true

    func perform() throws -> some IntentResult {
        DispatchQueue.main.async {
            let recorder = WatchRecorderManager()
            if !recorder.isRecording {
                recorder.startRecording()
                WatchSession.shared.isRecordingUI = true
                print("⌚️ Started recording from Siri shortcut")
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
