import SwiftUI

struct LogFileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @State private var logText: String = ""

    private var accentColor: Color {
        if customAccentColorHex.isEmpty {
            return .blue
        } else {
            return Color(hex: customAccentColorHex) ?? .blue
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(colorScheme == .dark ? .black : .white)
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    Text(logText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .navigationTitle("idevice_log.txt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(accentColor)
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
