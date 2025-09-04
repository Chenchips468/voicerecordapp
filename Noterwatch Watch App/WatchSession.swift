import Foundation
import WatchConnectivity
import Combine

final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSession()

    @Published var isReachable = false
    @Published var status: String = "Ready"
    @Published var liveText: String = ""
    @Published var isRecordingUI = false

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
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("⌚️ Reachability changed: \(session.isReachable)")
        }
    }

    // MARK: - Sending commands to iPhone

    func sendCommand(_ command: String) {
        print("⌚️ Attempting to send command: \(command)")

        guard WCSession.default.isReachable else {
            print("⚠️ iPhone not reachable, cannot send command: \(command)")
            DispatchQueue.main.async {
                self.status = "iPhone not reachable"
            }
            return
        }

        WCSession.default.sendMessage(
            ["command": command],
            replyHandler: { reply in
                print("✅ Command '\(command)' delivered, reply: \(reply)")
            },
            errorHandler: { error in
                print("❌ Failed to send command '\(command)': \(error.localizedDescription)")
            }
        )

        DispatchQueue.main.async {
            if command == "start" {
                self.status = "Recording…"
            } else if command == "stop" {
                self.status = "Stopped"
            }
        }
    }

    // MARK: - Sending recordings to iPhone

    func sendRecording(fileURL: URL) {
        guard WCSession.default.activationState == .activated else {
            print("❌ Cannot send recording: WCSession not activated")
            DispatchQueue.main.async {
                self.status = "Error: Watch not connected"
            }
            return
        }
        
        guard WCSession.default.isReachable else {
            print("❌ Cannot send recording: iPhone not reachable")
            DispatchQueue.main.async {
                self.status = "Error: iPhone not reachable"
            }
            return
        }
        
        // Verify file exists and is m4a
        guard fileURL.pathExtension.lowercased() == "m4a",
              FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Invalid file or not m4a format: \(fileURL.lastPathComponent)")
            DispatchQueue.main.async {
                self.status = "Error: Invalid file"
            }
            return
        }
        
        print("⌚️ Starting file transfer: \(fileURL.lastPathComponent)")
        print("⌚️ This file will trigger session(_ session: WCSession, didReceive file:) on iPhone")
        
        let transfer = WCSession.default.transferFile(fileURL, metadata: ["type": "recording"])
        
        // Monitor transfer progress
        transfer.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                let percentage = Int(progress.fractionCompleted * 100)
                self.status = "Sending: \(percentage)%"
                print("⌚️ Transfer progress: \(percentage)% - Will be received by iPhone's didReceive delegate")
            }
        }
        
        print("⌚️ Initiated file transfer to iPhone's didReceive delegate method")
    }
    
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ File transfer failed: \(error.localizedDescription)")
                self.status = "Error: Transfer failed"
            } else {
                print("✅ File transfer completed successfully")
                self.status = "Transfer complete"
            }
        }
    }

    // MARK: - Receiving messages from iPhone

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("⌚️ Watch received message from iPhone: \(message)")
        DispatchQueue.main.async {
            if let s = message["status"] as? String {
                self.status = s
            }
            if let t = message["transcription"] as? String {
                self.liveText = t
            }
        }
    }
}
/*final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSession()

    @Published var isReachable = false
    @Published var status: String = "Ready"
    @Published var liveText: String = ""
    @Published var isRecordingUI = false

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
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("⌚️ Reachability changed: \(session.isReachable)")
        }
    }

    // MARK: - Sending commands to iPhone

    func sendCommand(_ command: String) {
        print("⌚️ Attempting to send command: \(command)")

        guard WCSession.default.isReachable else {
            print("⚠️ iPhone not reachable, cannot send command: \(command)")
            DispatchQueue.main.async {
                self.status = "iPhone not reachable"
            }
            return
        }

        WCSession.default.sendMessage(
            ["command": command],
            replyHandler: { reply in
                print("✅ Command '\(command)' delivered, reply: \(reply)")
            },
            errorHandler: { error in
                print("❌ Failed to send command '\(command)': \(error.localizedDescription)")
            }
        )

        DispatchQueue.main.async {
            if command == "start" {
                self.status = "Recording…"
            } else if command == "stop" {
                self.status = "Stopped"
            }
        }
    }

    // MARK: - Receiving messages from iPhone

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("⌚️ Watch received message from iPhone: \(message)")
        DispatchQueue.main.async {
            if let s = message["status"] as? String {
                self.status = s
            }
            if let t = message["transcription"] as? String {
                self.liveText = t
            }
        }
    }
}
*/
