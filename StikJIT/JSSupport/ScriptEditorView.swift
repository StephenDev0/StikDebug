//
//  ScriptEditorView.swift
//  StikDebug
//
//  Created by s s on 2025/7/4.
//

import SwiftUI
import CodeEditorView
import LanguageSupport

struct ScriptEditorView: View {
    let scriptURL: URL

    @State private var scriptContent: String = ""
    @State private var position: CodeEditor.Position = .init()
    @State private var messages: Set<TextLocated<Message>> = []

    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeExpansionManager) private var themeExpansion

    private var backgroundStyle: BackgroundStyle { themeExpansion?.backgroundStyle(for: appThemeRaw) ?? AppTheme.system.backgroundStyle }
    private var preferredScheme: ColorScheme? { themeExpansion?.preferredColorScheme(for: appThemeRaw) }
    private var editorTheme: Theme {
        colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight
    }

    var body: some View {
        ZStack {
            ThemedBackground(style: backgroundStyle)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                CodeEditor(
                    text:     $scriptContent,
                    position: $position,
                    messages: $messages,
                    language: .swift()
                )
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.codeEditorTheme, editorTheme)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle(scriptURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadScript)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveScript()
                    dismiss()
                }
            }
        }
        .preferredColorScheme(preferredScheme)
        .tint(colorScheme == .dark ? .white : .black)
        .toolbar(.hidden, for: .tabBar)
    }

    private func loadScript() {
        scriptContent = (try? String(contentsOf: scriptURL)) ?? ""
    }

    private func saveScript() {
        try? scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
    }
}
