import Foundation

struct QueuedRecording: Codable {
    let fileURL: String
    let timestamp: Date
    let isUploaded: Bool
}

class RecordingQueue: ObservableObject {
    static let shared = RecordingQueue()
    
    @Published private(set) var recordings: [QueuedRecording] = []
    private let queue = UserDefaults.standard
    private let queueKey = "watchOfflineRecordingQueue"
    
    private init() {
        loadQueue()
    }
    
    private func loadQueue() {
        if let data = queue.data(forKey: queueKey),
           let decoded = try? JSONDecoder().decode([QueuedRecording].self, from: data) {
            recordings = decoded
        }
    }
    
    private func saveQueue() {
        if let encoded = try? JSONEncoder().encode(recordings) {
            queue.set(encoded, forKey: queueKey)
        }
    }
    
    func addRecording(fileURL: URL) {
        let recording = QueuedRecording(
            fileURL: fileURL.path,
            timestamp: Date(),
            isUploaded: false
        )
        recordings.append(recording)
        saveQueue()
        print(recordings.count)
    }
    
    func markAsUploaded(fileURL: URL) {
        if let index = recordings.firstIndex(where: { $0.fileURL == fileURL.path }) {
            recordings.remove(at: index)
            saveQueue()
        }
    }
    
    func getPendingRecordings() -> [URL] {
        var validURLs: [URL] = []
        for recording in recordings where !recording.isUploaded {
            let filePath = recording.fileURL
            if FileManager.default.fileExists(atPath: filePath) {
                validURLs.append(URL(fileURLWithPath: filePath))
            } else {
                markAsUploaded(fileURL: URL(fileURLWithPath: filePath))
            }
        }
        return validURLs
    }
}
