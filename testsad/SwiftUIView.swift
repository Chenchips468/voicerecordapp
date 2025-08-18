import SwiftUI
import AppIntents
import Speech
import AVFoundation
import UIKit

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
                    try? speechRecognizer.startRecording()
                }

                Button("Stop Recording") {
                    speechRecognizer.stopRecording()
                    speechRecognizer.saveToTxt()
                }
            }

            Button("Open TXT") {
                speechRecognizer.openTxt()
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
                try? speechRecognizer.startRecording()
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
    
    override init() {
        super.init()
        requestPermissions()
    }
    
    func requestPermissions() {
        // Speech recognition permission
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized: print("✅ Speech recognition authorized")
                default: print("❌ Speech recognition not authorized")
                }
            }
        }
        
        // Microphone permission
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
    
    func startRecording() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
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
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }
    
    func saveToTxt() {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Transcription.txt")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        
        let entry = "\n[\(timestamp)]\n\(transcribedText)\n"
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // Append if file exists
                let handle = try FileHandle(forWritingTo: fileURL)
                handle.seekToEndOfFile()
                if let data = entry.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            } else {
                // Create new file
                try entry.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            print("💾 Appended TXT at: \(fileURL)")
        } catch {
            print("❌ Error saving file: \(error)")
        }
    }
    
    func openTxt() {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Transcription.txt")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ File does not exist")
            return
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
