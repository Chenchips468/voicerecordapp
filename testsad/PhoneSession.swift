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
