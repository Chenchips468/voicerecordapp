import SwiftUI

@main
struct TestsadApp: App {
    @StateObject private var phoneSession = PhoneSessionManager.shared
    
    var body: some Scene {
        WindowGroup {
            ScrollView {
                VStack(alignment: .leading) {
                    PhoneRecordMp3()
                    m4atotext()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .environmentObject(phoneSession)
            }
        }
    }
}
