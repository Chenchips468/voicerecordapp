import Foundation
import WatchConnectivity
import SwiftUI

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()
    
    @Published var currentDate: Date?
    
    private override init() {
        super.init()
        print("📱 PhoneSessionManager init, about to activate WCSession")
        activateSession()
    }
    
    private func activateSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("📱 PhoneSessionManager activated session, delegate=\(session.delegate!)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session after deactivation
        WCSession.default.activate()
    }
    
    // Called when the Watch sends a file
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("📱 Phone's didReceive delegate called by Watch's transferFile")
        print("📱 Received file: \(file.fileURL.lastPathComponent)")
        
        var isQueuedRecording = false
        if let metadata = file.metadata {
            print("📱 File metadata: \(metadata)")
            if metadata["queued"] as? Bool == true {
                print("📱 Processing queued recording from offline mode")
                isQueuedRecording = true
            }
        }
        
        let fileURL = file.fileURL
        guard fileURL.pathExtension.lowercased() == "m4a" else {
            print("❌ Received file is not an m4a: \(fileURL.lastPathComponent)")
            return
        }
        print("✅ Received valid m4a file from Watch's transferFile")
        
        if isQueuedRecording {
            print("📱 Processing queued recording from offline mode")
            // Send acknowledgment back to watch
            if session.isReachable {
                session.sendMessage(
                    ["status": "Queued recording received"],
                    replyHandler: nil,
                    errorHandler: { error in
                        print("❌ Failed to send queue acknowledgment: \(error.localizedDescription)")
                    }
                )
            }
        }
        
        // Add the received file to recordings
        DispatchQueue.main.async {
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsURL.appendingPathComponent(file.fileURL.lastPathComponent)
            do {
                // Remove existing file if it exists
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                // Copy the system-provided file URL (already on iPhone) to Documents
                try fileManager.copyItem(at: file.fileURL, to: destinationURL)
                print("📱 Copied received file to Documents: \(destinationURL.lastPathComponent)")
                AudioRecorderManager.shared.addRecording(from: destinationURL)
                print("✅ Recording added successfully - Transfer complete")
            } catch {
                print("❌ Failed to copy received file: \(error.localizedDescription)")
            }
        }
    }
    
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            print("❌ File transfer failed: \(error.localizedDescription)")
        } else {
            print("✅ File transfer completed successfully")
        }
    }

    // Handles direct message requests from the Watch, including date requests
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print(" Received request")
        if let request = message["request"] as? String, request == "date" {
            print("📱 Received date request from Watch")
            replyHandler(["date": Date()])
        } else {
            replyHandler([:])
        }
    }
}

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📱 Reachability changed: \(session.isReachable)")
        if session.isReachable {
            // Send ready status to watch when connection is restored
            session.sendMessage(
                ["status": "Phone connected - Ready for sync"],
                replyHandler: nil,
                errorHandler: { error in
                    print("❌ Failed to send ready status: \(error.localizedDescription)")
                }
            )
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("📱 didReceiveUserInfo called: \(userInfo)")
        
        guard let cmd = userInfo["command"] as? String else {
            print("⚠️ Unknown userInfo payload: \(userInfo)")
            return
        }
        
        print("📱 Handling queued command: \(cmd)")
        DispatchQueue.main.async {
            switch cmd {
            case "start":
                print("🎙 Received 'start' command from queued Watch command")
            case "stop":
                print("🛑 Received 'stop' command from queued Watch command")
                // Optionally push status back to Watch
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(["status": "Saved ✓"], replyHandler: nil, errorHandler: nil)
                }
            default:
                print("⚠️ Unrecognized queued command: \(cmd)")
            }
        }
    }


// MARK: - Receiving messages

