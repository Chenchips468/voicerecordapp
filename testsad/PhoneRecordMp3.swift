import SwiftUI
import AVFoundation

struct Recording: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let date: Date
    let location: String
}

class AudioRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let shared = AudioRecorderManager()
    
    @Published var recordings: [Recording] = []
    @Published var currentLevel: Float = 0.0
    
    var audioRecorder: AVAudioRecorder?
    var audioPlayers: [UUID: AVPlayer] = [:]
    var levelTimer: Timer?
    
    let recordingsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    private override init() {
        super.init()
        fetchRecordings()
    }
    
    func fetchRecordings() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: recordingsFolder, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey], options: .skipsHiddenFiles)
            let m4aFiles = fileURLs.filter { $0.pathExtension == "m4a" }
            
            let sortedFiles = try m4aFiles.sorted { (url1, url2) -> Bool in
                let values1 = try url1.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                let values2 = try url2.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                
                let date1 = values1.creationDate ?? values1.contentModificationDate ?? Date.distantPast
                let date2 = values2.creationDate ?? values2.contentModificationDate ?? Date.distantPast
                
                return date1 > date2
            }
            
            let loadedRecordings = try sortedFiles.map { url -> Recording in
                let values = try url.resourceValues(forKeys: [.creationDateKey])
                let creationDate = values.creationDate ?? Date()
                return Recording(url: url, name: url.lastPathComponent, date: creationDate, location: "Unknown")
            }
            
            DispatchQueue.main.async {
                self.recordings = loadedRecordings
            }
        } catch {
            print("Failed to fetch recordings: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "recording on \(dateString) - \(UUID().uuidString).m4a"
        let fileURL = recordingsFolder.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            if audioRecorder?.record() == true {
                print("Recording started at \(fileURL)")
                startLevelTimer()
            } else {
                print("Failed to start recording: AVAudioRecorder.record() returned false")
            }
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        guard let recorder = audioRecorder else { return }
        let fileURL = recorder.url
        recorder.stop()
        audioRecorder = nil
        stopLevelTimer()
        currentLevel = 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let values = try? fileURL.resourceValues(forKeys: [.creationDateKey])
            let creationDate = values?.creationDate ?? Date()
            let recording = Recording(url: fileURL, name: fileURL.lastPathComponent, date: creationDate, location: "Unknown")
            print(self.recordings.count)
            self.recordings.insert(recording, at: 0)
            print(self.recordings.count)
        }
    }
    
    func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.audioRecorder?.updateMeters()
            if let power = self.audioRecorder?.averagePower(forChannel: 0) {
                // Convert from dB (-160…0) to 0…1
                let level = max(0, min(1, (power + 160) / 160))
                self.currentLevel = level
            }
        }
        RunLoop.current.add(levelTimer!, forMode: .common)
    }
    
    func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    func playRecording(_ recording: Recording) {
        guard FileManager.default.fileExists(atPath: recording.url.path) else {
            print("File does not exist: \(recording.url.path)")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        if let player = audioPlayers[recording.id] {
            player.play()
        } else {
            let player = AVPlayer(url: recording.url)
            audioPlayers[recording.id] = player
            player.play()
        }
    }
    
    func pauseRecording(_ recording: Recording) {
        if let player = audioPlayers[recording.id] {
            player.pause()
        }
    }
    
    func stopRecordingFor(_ recording: Recording) {
        if let player = audioPlayers[recording.id] {
            player.pause()
            player.seek(to: CMTime.zero)
        }
    }
    
    func clearAllRecordings() {
        for rec in recordings {
            try? FileManager.default.removeItem(at: rec.url)
            audioPlayers[rec.id]?.pause()
            audioPlayers[rec.id] = nil
        }
        recordings.removeAll()
    }

    /// Add a new recording from the specified URL and insert it into the recordings list.
    func addRecording(from url: URL) {
        let values = try? url.resourceValues(forKeys: [.creationDateKey])
        let creationDate = values?.creationDate ?? Date()
        let recording = Recording(url: url, name: url.lastPathComponent, date: creationDate, location: "Unknown")
        DispatchQueue.main.async {
            print(self.recordings.count)
            self.recordings.insert(recording, at: 0)
            print(self.recordings.count)
        }
    }
}

struct PhoneRecordMp3: View {
    @StateObject private var recorder = AudioRecorderManager.shared
    @State private var isRecording = false
    
    var body: some View {
        NavigationView {
            VStack {
                Button(action: {
                    if isRecording {
                        recorder.stopRecording()
                    } else {
                        recorder.startRecording()
                    }
                    isRecording.toggle()
                }) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isRecording ? Color.red : Color.blue)
                        .cornerRadius(8)
                        .padding()
                }
                
                if isRecording {
                    ProgressView(value: recorder.currentLevel)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .padding([.leading, .trailing], 20)
                }
                
                if !recorder.recordings.isEmpty {
                    Button("Clear All") {
                        recorder.clearAllRecordings()
                    }
                    .foregroundColor(.red)
                    .padding(.bottom, 10)
                }
                
                List(recorder.recordings) { rec in
                    VStack(alignment: .leading) {
                        Text(rec.name)
                            .font(.headline)
                        Text("Date: \(rec.date.formatted(date: .numeric, time: .shortened))")
                            .font(.subheadline)
                        Text("Location: \(rec.location)")
                            .font(.subheadline)
                    }
                    HStack {
                        Spacer()
                        Button("Play") {
                            recorder.playRecording(rec)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Button("Pause") {
                            recorder.pauseRecording(rec)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Button("Stop") {
                            recorder.stopRecordingFor(rec)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .navigationTitle("Recordings")
        }
    }
}

#Preview {
    PhoneRecordMp3()
}
