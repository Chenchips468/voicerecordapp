import SwiftUI
import AppIntents
import Speech
import AVFoundation
import UIKit
/*
// MARK: - ContentView
struct SwiftUIView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var openedViaShortcut = false

    var body: some View {
        VStack(spacing: 20) {
            Text(openedViaShortcut ? "Recording via Shortcut..." : "Ready")
                .font(.title)
                .padding()
                .frame(height: 200)
                .border(Color.gray)

            Text(speechRecognizer.transcribedText)
                .padding()
                .frame(height: 200)
                .border(Color.gray)

            HStack(spacing: 40) {
                Button("Start Recording") {
                    Task {
                        await speechRecognizer.restartRecording()
                    }
                }

                Button("Stop Recording") {
                    speechRecognizer.stopRecording()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        speechRecognizer.saveToTxt()
                    }
                }
            }

            Button("Open TXT") {
                speechRecognizer.openTxt()
            }
            
            Button("Clear TXT") {
                speechRecognizer.clearTxt()
            }
        }
        .padding()
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                print("🟢 App active")
            }
        }
        .onOpenURL { url in
            if url.scheme == "testsadapp", url.host == "startRecording" {
                print("🚀 App opened via Shortcut to start recording")
                openedViaShortcut = true

                // Delay to allow Siri to release microphone
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    await speechRecognizer.restartRecording()
                }
            }
        }
    }
}

// MARK: - Speech Recognizer
class SpeechRecognizer: NSObject, ObservableObject, UIDocumentInteractionControllerDelegate {
    @Published var transcribedText = ""
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 10.0
    private var hasUnsavedTranscription = false
    
    override init() {
        super.init()
        requestPermissions()
    }
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized: print("✅ Speech recognition authorized")
                default: print("❌ Speech recognition not authorized")
                }
            }
        }
        
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                print(granted ? "✅ Microphone access granted" : "❌ Microphone access denied")
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                print(granted ? "✅ Microphone access granted" : "❌ Microphone access denied")
            }
        }
    }
    
    func restartRecording() async {
        if audioEngine.isRunning {
            stopRecording()
        }
        resetRecognition()
        
        // Small delay to allow SFSpeechRecognizer to fully reset
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s
        
        do {
            try startRecording()
        } catch {
            print("❌ Failed to start recording: \(error)")
        }
    }
    
    private func resetRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine.stop()
        audioEngine.reset()
        transcribedText = ""
        hasUnsavedTranscription = false
    }
    
    func startRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.hasUnsavedTranscription = true
                }
                self.resetSilenceTimer()
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        print("🎙 Listening...")
        resetSilenceTimer()
    }
    
    func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.stopRecording()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.saveToTxt()
            }
            print("⏰ Auto-stopped recording due to 10 seconds of silence")
        }
    }
    
    func stopRecording() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            print("🛑 Recording stopped")
        }
    }
    
    func saveToTxt() {
        guard hasUnsavedTranscription else {
            print("⚠️ No new transcription to save. Skipping.")
            return
        }
        
        if transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("⚠️ transcribedText is empty or whitespace only. Skipping save.")
            return
        }
        
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Transcription.txt")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        
        let entry = "\n[\(timestamp)]\n\(transcribedText)\n"
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let oldContent = try String(contentsOf: fileURL, encoding: .utf8)
                let newContent = entry + oldContent
                try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            } else {
                try entry.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            print("💾 Updated TXT at: \(fileURL)")
            hasUnsavedTranscription = false
            transcribedText = ""
        } catch {
            print("❌ Error saving file: \(error)")
        }
    }
    
    func openTxt() {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Transcription.txt")
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try "".write(to: fileURL, atomically: true, encoding: .utf8)
                print("🆕 Created empty Transcription.txt file")
            } catch {
                print("❌ Error creating empty Transcription.txt: \(error)")
                return
            }
        }
        
        let controller = UIDocumentInteractionController(url: fileURL)
        controller.delegate = self
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                controller.presentPreview(animated: true)
            }
        }
    }
    
    // UIDocumentInteractionControllerDelegate
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        let windowScene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        return windowScene.windows.first!.rootViewController!
    }
    
    func clearTxt() {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Transcription.txt")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Transcription.txt cleared")
            } catch {
                print("❌ Error clearing Transcription.txt: \(error)")
            }
        } else {
            print("ℹ️ Transcription.txt does not exist to clear")
        }
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            print("🆕 Created empty Transcription.txt file after clearing")
        } catch {
            print("❌ Error creating empty Transcription.txt after clearing: \(error)")
        }
    }
}

// MARK: - Siri Shortcut Intent
struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        print("⚡ Shortcut triggered")

        if let url = URL(string: "testsadapp://startRecording") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }

        return .result()
    }
}

// MARK: - App Shortcuts Provider
struct MyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: ["Start recording in \(.applicationName)"],
            shortTitle: "Start Recording",
            systemImageName: "mic.fill"
        )
    }
}

// MARK: - Preview
#Preview {
    SwiftUIView()
}
*/
