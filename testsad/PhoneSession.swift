import Foundation
import WatchConnectivity
import SwiftUI

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()
    
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
        
        if let metadata = file.metadata {
            print("📱 File metadata: \(metadata)")
        }
        
        let fileURL = file.fileURL
        guard fileURL.pathExtension.lowercased() == "m4a" else {
            print("❌ Received file is not an m4a: \(fileURL.lastPathComponent)")
            return
        }
        print("✅ Received valid m4a file from Watch's transferFile")
        
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
}
/*
import Foundation
import WatchConnectivity

final class PhoneSession: NSObject, WCSessionDelegate {
    static let shared = PhoneSession()
    var speechRecognizer: SpeechRecognizer?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("📱 WCSession activated on iPhone")
        } else {
            print("❌ WCSession not supported on this device")
        }
    }

    // MARK: - WCSessionDelegate required methods

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("📱 WCSession activationDidComplete: state=\(activationState.rawValue)")
        if let error = error {
            print("❌ WCSession activation error: \(error.localizedDescription)")
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession did become inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession did deactivate — reactivating")
        session.activate()
    }
    #endif

    // MARK: - Receiving messages

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📱 Received message (no reply): \(message)")
        handle(message: message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        print("📱 Received message with reply: \(message)")
        handle(message: message)
        replyHandler(["ok": true])
    }

    private func handle(message: [String: Any]) {
        guard let cmd = message["command"] as? String else {
            print("⚠️ Unknown message: \(message)")
            return
        }

        print("📱 Handling command: \(cmd)")
        DispatchQueue.main.async {
            switch cmd {
            case "start":
                print("🎙 Starting recording from Watch command")
                Task { [weak self] in
                    await self?.speechRecognizer?.restartRecording()
                }
            case "stop":
                print("🛑 Stopping recording from Watch command")
                self.speechRecognizer?.stopRecording()
                self.speechRecognizer?.saveToTxt()
                self.pushMinimalStatusToWatch(text: "Saved ✓")
            default:
                print("⚠️ Unrecognized command: \(cmd)")
            }
        }
    }

    // MARK: - Sending updates back to watch

    func pushMinimalStatusToWatch(text: String) {
        guard WCSession.default.isReachable else {
            print("⚠️ Tried to send status but watch not reachable")
            return
        }
        print("📱 Sending status update to Watch: \(text)")
        WCSession.default.sendMessage(["status": text], replyHandler: nil, errorHandler: { error in
            print("❌ Failed to send status: \(error.localizedDescription)")
        })
    }

    func pushTranscriptionToWatch(_ text: String) {
        guard WCSession.default.isReachable else {
            print("⚠️ Tried to send transcription but watch not reachable")
            return
        }
        print("📱 Sending transcription update to Watch: \(text)")
        WCSession.default.sendMessage(["transcription": text], replyHandler: nil, errorHandler: { error in
            print("❌ Failed to send transcription: \(error.localizedDescription)")
        })
    }
}
*/


    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📱 Reachability changed: \(session.isReachable)")
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("📱 didReceiveUserInfo called: \(userInfo)")
    }
