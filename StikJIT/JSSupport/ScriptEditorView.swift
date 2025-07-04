//
//  ScriptEditorView.swift
//  StikDebug
//
//  Created by s s on 2025/7/4.
//

import SwiftUI

struct ScriptEditorView: View {
    let scriptURL: URL
    @State private var scriptContent: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            TextEditor(text: $scriptContent)
                .padding()
                .border(Color.gray, width: 1)
                .navigationTitle(scriptURL.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .font(.system(.footnote, design: .monospaced))

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    saveScript()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear(perform: loadScript)
    }

    private func loadScript() {
        scriptContent = (try? String(contentsOf: scriptURL)) ?? ""
    }

    private func saveScript() {
        try? scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
    }
}
