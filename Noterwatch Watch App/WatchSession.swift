import Foundation
import WatchConnectivity
import Combine

final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSession()
    
    @Published var isReachable = false
    @Published var status: String = "Ready"
    @Published var liveText: String = ""
    @Published var isRecordingUI = false
    @Published var isOfflineMode = false
    
    private let recordingQueue = RecordingQueue.shared
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("⌚️ WCSession activated on Watch")
        } else {
            print("❌ WCSession not supported on Watch")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("⌚️ WCSession activationDidComplete: state=\(activationState.rawValue)")
        if let error = error {
            print("❌ WCSession activation error: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        // Add delay before syncing queued recordings to ensure session is fully ready
        if activationState == .activated && session.isReachable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.syncQueuedRecordings()
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isOfflineMode = !session.isReachable
            print("⌚️ Reachability changed: \(session.isReachable)")
            
            if session.isReachable && session.activationState == .activated {
                // Add delay before syncing queued recordings to ensure session is fully ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.syncQueuedRecordings()
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("⌚️ Received message from phone: \(message)")
        // Handle incoming messages from the phone here as needed
        
        // For example, if you expect a "ping" command, reply with "pong"
        if let command = message["command"] as? String {
            switch command {
            case "ping":
                replyHandler(["response": "pong"])
            default:
                replyHandler(["response": "unknown command"])
            }
        } else {
            replyHandler(["response": "no command found"])
        }
    }
    
    private func handleOfflineRecording(_ fileURL: URL) {
        DispatchQueue.main.async {
            self.status = "Saved for later sync"
            self.recordingQueue.addRecording(fileURL: fileURL)
            self.isOfflineMode = true
        }
    }
    
    private func syncQueuedRecordings() {
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            print("⌚️ Cannot sync queued recordings: session not fully activated or not reachable")
            return
        }
        
        let pendingRecordings = recordingQueue.getPendingRecordings()
        guard !pendingRecordings.isEmpty else { return }
        
        print("⌚️ Syncing \(pendingRecordings.count) queued recordings")
        
        for fileURL in pendingRecordings {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            
            // Use original recording timestamp and location
            let queuedRecording = recordingQueue.recordings.first { $0.fileURL == fileURL.path }
            let timestamp = queuedRecording?.timestamp.timeIntervalSince1970 ?? Date().timeIntervalSince1970
            let location = queuedRecording?.location ?? "Unknown"
            
            print("⌚️ Syncing queued recording: \(fileURL.lastPathComponent)")
            let transfer = WCSession.default.transferFile(fileURL, metadata: [
                "type": "recording",
                "queued": true,
                "date": timestamp,
                "location": location
            ])
            
            transfer.progress.observe(\.fractionCompleted) { progress, _ in
                DispatchQueue.main.async {
                    let percentage = Int(progress.fractionCompleted * 100)
                    self.status = "Syncing queued: \(percentage)%"
                }
            }
        }
    }
    
    // MARK: - Sending commands to iPhone
    
    func sendCommand(_ command: String) {
        print("⌚️ Attempting to send command: \(command)")
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                ["command": command],
                replyHandler: { reply in
                    print("✅ Command '\(command)' delivered immediately, reply: \(reply)")
                },
                errorHandler: { error in
                    print("❌ Failed immediate send of '\(command)': \(error.localizedDescription)")
                }
            )
            DispatchQueue.main.async {
                if command == "start" {
                    self.status = "Recording…"
                } else if command == "stop" {
                    self.status = "Stopped"
                }
            }
        } else {
            WCSession.default.transferUserInfo(["command": command])
            print("⌚️ Queued command '\(command)' for later delivery")
            
            DispatchQueue.main.async {
                if command == "start" {
                    self.status = "Queued: Recording…"
                } else if command == "stop" {
                    self.status = "Queued: Stopped"
                } else {
                    self.status = "Queued: \(command)"
                }
            }
        }
    }
    
    // MARK: - Sending recordings to iPhone
    
    func sendRecording(fileURL: URL) {
        print("⌚️ Attempting to send recording: \(fileURL.lastPathComponent)")
        
        guard WCSession.default.activationState == .activated else {
            print("❌ Cannot send recording: WCSession not activated")
            handleOfflineRecording(fileURL)
            return
        }
        
        guard WCSession.default.isReachable else {
            print("❌ Cannot send recording: iPhone not reachable")
            handleOfflineRecording(fileURL)
            return
        }
        
        guard fileURL.pathExtension.lowercased() == "m4a",
              FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Invalid file or not m4a format: \(fileURL.lastPathComponent)")
            DispatchQueue.main.async {
                self.status = "Error: Invalid file"
            }
            return
        }
        
        print("⌚️ Requesting date from phone before sending recording")
        WCSession.default.sendMessage(
            ["request": "date"],
            replyHandler: { reply in
                if let _ = reply["date"] as? Date {
                    print("⌚️ Received date from phone, proceeding with recording transfer")
                    self.proceedWithRecordingTransfer(fileURL)
                    self.syncQueuedRecordings()
                } else {
                    print("❌ No date received from phone, queueing recording")
                    self.handleOfflineRecording(fileURL)
                }
            },
            errorHandler: { error in
                print("❌ Failed to request date: \(error.localizedDescription)")
                self.handleOfflineRecording(fileURL)
            }
        )
    }
    
    private func proceedWithRecordingTransfer(_ fileURL: URL) {
        print("⌚️ Starting file transfer: \(fileURL.lastPathComponent)")
        print("⌚️ This file will trigger session(_ session: WCSession, didReceive file:) on iPhone")
        
        let metadata: [String: Any] = [
            "type": "recording",
            "date": Date().timeIntervalSince1970,
            "location": "Unknown"
        ]
        let transfer = WCSession.default.transferFile(fileURL, metadata: metadata)
        
        transfer.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                let percentage = Int(progress.fractionCompleted * 100)
                self.status = "Sending: \(percentage)%"
                print("⌚️ Transfer progress: \(percentage)% - Will be received by iPhone's didReceive delegate")
            }
        }
        
        print("⌚️ Initiated file transfer to iPhone's didReceive delegate method")
    }
    
    private func syncAndClearQueuedRecordings() {
        let pendingRecordings = recordingQueue.getPendingRecordings()
        guard !pendingRecordings.isEmpty else { return }
        
        print("⌚️ Syncing and clearing \(pendingRecordings.count) queued recordings")
        for fileURL in pendingRecordings {
            print("⌚️ Checking file existence for \(fileURL.path)")
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            
            let queuedRecording = recordingQueue.recordings.first { $0.fileURL == fileURL.path }
            let timestamp = queuedRecording?.timestamp.timeIntervalSince1970 ?? Date().timeIntervalSince1970
            let location = queuedRecording?.location ?? "Unknown"
            
            print("⌚️ Syncing queued recording: \(fileURL.lastPathComponent)")
            let transfer = WCSession.default.transferFile(fileURL, metadata: [
                "type": "recording",
                "queued": true,
                "date": timestamp,
                "location": location
            ])
            
            transfer.progress.observe(\.fractionCompleted) { progress, _ in
                DispatchQueue.main.async {
                    let percentage = Int(progress.fractionCompleted * 100)
                    self.status = "Syncing queued: \(percentage)%"
                }
            }
        }
    }
    
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ File transfer failed: \(error.localizedDescription)")
                self.status = "Error: Transfer failed"
                // Do not mark as uploaded; keep in queue for retry
            } else {
                print("✅ File transfer completed successfully")
                self.status = "Transfer complete"
                
                if let metadata = fileTransfer.file.metadata as? [String: Any],
                   let queued = metadata["queued"] as? Bool,
                   queued == true {
                    self.recordingQueue.markAsUploaded(fileURL: fileTransfer.file.fileURL)
                }
            }
        }
    }
}
