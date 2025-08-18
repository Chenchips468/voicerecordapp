import SwiftUI
import AppIntents
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var openedViaSiri = false
    
    var body: some View {
        ZStack {
            // Background color changes if opened via Siri
            (openedViaSiri ? Color.red : Color.white)
                .ignoresSafeArea()
            
            Text(openedViaSiri ? "Opened via Siri!" : "Check Xcode console for launch type")
                .padding()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                print("🟢 App became active (normal launch or back from background)")
            }
        }
        .onOpenURL { url in
            if url.scheme == "testsadApp", url.host == "takeNotes" {
                print("🚀 App opened via Siri shortcut URL")
                openedViaSiri = true
            }
        }
    }
}

// MARK: - Siri Shortcut Intent
struct TakeNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Take Notes"

    // Launch app automatically when shortcut runs
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        print("⚡ Shortcut triggered in AppIntent")

        // Open the app via URL so ContentView can detect it
        if let url = URL(string: "testsadApp://takeNotes") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }

        return .result()
    }
}
/*
// MARK: - Register Shortcut
struct MyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TakeNotesIntent(),
            phrases: ["Be cool in \(.applicationName)"],
            shortTitle: "Take Notes For Me",
            systemImageName: "note.text"
        )
    }
}

#Preview {
    ContentView()
}
*/
