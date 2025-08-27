import SwiftUI

struct WatchContentView: View {
    @StateObject private var wc = WatchSession.shared
    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 8) {
            Text(wc.status).font(.caption).lineLimit(1)

            ScrollView {
                Text(wc.liveText.isEmpty ? " " : wc.liveText)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(isRecording ? "Stop" : "Start") {
                if isRecording {
                    wc.sendCommand("stop")
                } else {
                    print("got here")
                    wc.sendCommand("start")
                }
                isRecording.toggle()
            }
            .buttonStyle(.borderedProminent)
            //.disabled(!wc.isReachable)
        }
        .padding()
    }
}
