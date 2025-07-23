import SwiftUI

struct LogFileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logText: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                Text(logText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("idevice_log.txt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: loadLog)
    }

    private func loadLog() {
        let logPath = URL.documentsDirectory.appendingPathComponent("idevice_log.txt")
        if let content = try? String(contentsOf: logPath) {
            logText = content
        } else {
            logText = "Log file not found."
        }
    }
}
