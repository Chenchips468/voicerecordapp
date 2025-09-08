//
//  m4atotext.swift
//  testsad
//
//  Created by William Chen on 8/29/25.
//


import SwiftUI
import Speech
import UIKit

struct m4atotext: View {
    @State private var transcribedText: String = ""
    @State private var isAuthorized = false
    @State private var isTranscribing = false
    @State private var errorMessage: String?
    @State private var txtContent: String = ""

    @State private var recordings: [URL] = []
    @State private var timer: Timer?
    @State private var transcriptions: [(date: Date, text: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recordings:")
                .font(.headline)
            List {
                ForEach(recordings, id: \.self) { recording in
                    Button(action: {
                        transcribeAudio(url: recording)
                    }) {
                        Text(recording.lastPathComponent)
                    }
                }
            }
            .frame(height: 200)
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            }
            Text("Transcribed Text:")
                .font(.headline)
            TextEditor(text: $transcribedText)
                .frame(minHeight: 200)
                .border(Color.gray, width: 1)
                .disabled(true)
            Button("View All Transcriptions") {
                viewAllTranscriptions()
            }
            .padding(.top, 10)
            Button("Clear Transcriptions") {
                clearTranscriptions()
            }
            .padding(.top, 5)
            TextEditor(text: $txtContent)
                .frame(minHeight: 200)
                .border(Color.gray, width: 1)
        }
        .padding()
        .onAppear {
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    isAuthorized = (authStatus == .authorized)
                    if !isAuthorized {
                        errorMessage = "Speech recognition permission not granted."
                    }
                }
            }
            loadRecordings()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                loadRecordings()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func loadRecordings() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            recordings = files.filter { $0.pathExtension == "m4a" || $0.pathExtension == "mp3" }
        } catch {
            errorMessage = "Failed to load recordings: \(error.localizedDescription)"
        }
    }

    private func transcribeAudio(url: URL) {
        guard isAuthorized else {
            errorMessage = "Speech recognition permission not granted."
            return
        }
        transcribedText = ""
        errorMessage = nil
        isTranscribing = true
        let recognizer = SFSpeechRecognizer()
        guard let recognizer = recognizer, recognizer.isAvailable else {
            self.errorMessage = "Speech recognizer not available."
            self.isTranscribing = false
            return
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        recognizer.recognitionTask(with: request) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.transcriptions.insert((date: Date(), text: self.transcribedText), at: 0)
                    }
                }
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isTranscribing = false
                }
                if result?.isFinal == true {
                    self.isTranscribing = false
                }
            }
        }
    }
    
    private func clearTranscriptions() {
        transcriptions.removeAll()
        let fileURL = getTxtFileURL()
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            txtContent = ""
        } catch {
            errorMessage = "Failed to clear transcriptions: \(error.localizedDescription)"
        }
    }

    private func transcribeAndCollect(url: URL, completion: @escaping (String?, Date?) -> Void) {
        guard isAuthorized else {
            completion(nil, nil)
            return
        }
        let recognizer = SFSpeechRecognizer()
        guard let recognizer = recognizer, recognizer.isAvailable else {
            completion(nil, nil)
            return
        }
        // Get file creation date
        var creationDate: Date? = nil
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            creationDate = attrs[.creationDate] as? Date
        } catch {
            creationDate = nil
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        recognizer.recognitionTask(with: request) { result, error in
            if let result = result, result.isFinal {
                completion(result.bestTranscription.formattedString, creationDate)
            } else if error != nil {
                completion(nil, creationDate)
            }
        }
    }

    private func viewAllTranscriptions() {
        transcriptions.removeAll()
        errorMessage = nil
        txtContent = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        // Use sequential async calls to ensure order and correct appending
        let recordingsCopy = recordings
        func processNext(index: Int) {
            if index >= recordingsCopy.count {
                // Sort transcriptions by date descending (newest first)
                self.transcriptions.sort { $0.date > $1.date }
                // Rebuild txtContent in sorted order
                var rebuiltContent = ""
                for entry in self.transcriptions {
                    let dateString = dateFormatter.string(from: entry.date)
                    rebuiltContent.append("[\(dateString)] \(entry.text)\n")
                }
                DispatchQueue.main.async {
                    self.txtContent = rebuiltContent
                    let fileURL = self.getTxtFileURL()
                    do {
                        try self.txtContent.write(to: fileURL, atomically: true, encoding: .utf8)
                    } catch {
                        self.errorMessage = "Failed to update transcriptions: \(error.localizedDescription)"
                    }
                }
                return
            }
            let recording = recordingsCopy[index]
            transcribeAndCollect(url: recording) { text, creationDate in
                if let text = text {
                    let dateToUse = creationDate ?? Date()
                    DispatchQueue.main.async {
                        self.transcriptions.append((date: dateToUse, text: text))
                        // Process next after completion
                        processNext(index: index + 1)
                    }
                } else {
                    // Even if transcription fails, proceed to next
                    DispatchQueue.main.async {
                        processNext(index: index + 1)
                    }
                }
            }
        }
        processNext(index: 0)
    }

    private func getTxtFileURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("Transcriptions.txt")
    }
}

#Preview {
    m4atotext()
}
