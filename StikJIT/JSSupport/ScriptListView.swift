//
//  ScriptListView.swift
//  StikDebug
//
//  Created by s s on 2025/7/4.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ScriptListView: View {
    @State private var scripts: [URL] = []
    @State private var showNewFileAlert = false
    @State private var newFileName = ""
    @State private var showImporter = false
    @AppStorage(UserDefaults.Keys.defaultScriptName) private var defaultScriptName = UserDefaults.Keys.defaultScriptNameValue

    @State private var isBusy = false
    @State private var alertVisible = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var alertIsSuccess = false
    @State private var justCopied = false
    @State private var searchText = ""

    @State private var showDeleteConfirmation = false
    @State private var pendingDelete: URL? = nil

    var onSelectScript: ((URL?) -> Void)? = nil

    private var isPickerMode: Bool { onSelectScript != nil }

    private var filteredScripts: [URL] {
        guard !searchText.isEmpty else { return scripts }
        return scripts.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(searchText) }
    }


    var body: some View {
        NavigationStack {
            List {
                if isPickerMode {
                    Section {
                        Button {
                            onSelectScript?(nil)
                        } label: {
                            Label("No Script", systemImage: "nosign")
                        }
                    }
                }

                if filteredScripts.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(
                                isPickerMode ? "No scripts available" : "No scripts found",
                                systemImage: "doc.text.magnifyingglass"
                            )
                            .foregroundStyle(.secondary)
                            Text(isPickerMode ? "Import a file or choose None." : "Tap New or Import to get started.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section {
                        ForEach(filteredScripts, id: \.self) { script in
                            scriptRow(script)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if !isPickerMode {
                                        Button(role: .destructive) {
                                            pendingDelete = script
                                            showDeleteConfirmation = true
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                                .contextMenu {
                                    Button { copyName(script) } label: {
                                        Label("Copy Filename", systemImage: "doc.on.doc")
                                    }
                                    Button { copyPath(script) } label: {
                                        Label("Copy Path", systemImage: "folder")
                                    }
                                    if !isPickerMode {
                                        Button { saveDefaultScript(script) } label: {
                                            Label("Set Default", systemImage: "star")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            pendingDelete = script
                                            showDeleteConfirmation = true
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search scripts…"
            )
            .navigationTitle(isPickerMode ? "Choose Script" : "Scripts")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !isPickerMode {
                        Button { showNewFileAlert = true } label: {
                            Label("New", systemImage: "doc.badge.plus")
                        }
                        Button { showImporter = true } label: {
                            Label("Import", systemImage: "tray.and.arrow.down")
                        }
                    }
                }
            }
            .onAppear(perform: loadScripts)
            .alert("New Script", isPresented: $showNewFileAlert) {
                TextField("Filename", text: $newFileName)
                Button("Create", action: createNewScript)
                Button("Cancel", role: .cancel) { }
            }
            .alert("Delete Script?", isPresented: $showDeleteConfirmation, presenting: pendingDelete) { script in
                Button("Delete", role: .destructive) { deleteScript(script) }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { script in
                Text("Delete \(script.lastPathComponent)? This cannot be undone.")
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType(filenameExtension: "js") ?? .plainText]
            ) { result in
                switch result {
                case .success(let fileURL): importScript(from: fileURL)
                case .failure(let error): presentError(title: "Import Failed", message: error.localizedDescription)
                }
            }
        }
                .overlay {
            if isBusy {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView("Working…")
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if justCopied {
                VStack {
                    Spacer()
                    Text("Copied")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 30)
                }
                .animation(.easeInOut(duration: 0.25), value: justCopied)
            }
        }
        .alert(alertTitle, isPresented: $alertVisible) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func scriptRow(_ script: URL) -> some View {
        let isDefault = defaultScriptName == script.lastPathComponent
        if isPickerMode {
            Button {
                onSelectScript?(script)
            } label: {
                HStack {
                    Label(script.lastPathComponent, systemImage: "doc.text.fill")
                    Spacer()
                    if isDefault {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).imageScale(.small)
                    }
                }
            }
        } else {
            NavigationLink {
                ScriptEditorView(scriptURL: script)
            } label: {
                HStack {
                    Label(script.lastPathComponent, systemImage: "doc.text.fill")
                    Spacer()
                    if isDefault {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).imageScale(.small)
                    }
                }
            }
        }
    }

    // MARK: - File Ops

    private func scriptsDirectory() throws -> URL {
        let directory = try ScriptStore.prepareDirectory()
        try ensureEditorScripts(in: directory)
        return directory
    }

    private func ensureEditorScripts(in directory: URL) throws {
        let fm = FileManager.default
        let screenshotURL = directory.appendingPathComponent("screenshot-demo.js")
        if !fm.fileExists(atPath: screenshotURL.path) {
            try screenshotDemoScript.write(to: screenshotURL, atomically: true, encoding: .utf8)
        }
        let standaloneURL = directory.appendingPathComponent("screenshot-capture.js")
        if !fm.fileExists(atPath: standaloneURL.path) {
            try screenshotCaptureScript.write(to: standaloneURL, atomically: true, encoding: .utf8)
        }
    }

    private func loadScripts() {
        do {
            let directory = try scriptsDirectory()
            scripts = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "js" }
                .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        } catch {
            scripts = []
            presentError(title: "Unable to Load Scripts", message: error.localizedDescription)
        }
    }

    private func saveDefaultScript(_ url: URL) {
        defaultScriptName = url.lastPathComponent
        presentSuccess(title: "Default Script Set", message: url.lastPathComponent)
    }

    private func createNewScript() {
        guard !newFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var filename = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !filename.hasSuffix(".js") { filename += ".js" }
        do {
            let newURL = try scriptsDirectory().appendingPathComponent(filename)
            guard !FileManager.default.fileExists(atPath: newURL.path) else {
                presentError(title: "Failed to Create New Script", message: "A script with the same name already exists.")
                return
            }
            try "".write(to: newURL, atomically: true, encoding: .utf8)
            newFileName = ""
            loadScripts()
            presentSuccess(title: "Created", message: filename)
        } catch {
            presentError(title: "Error Creating File", message: error.localizedDescription)
        }
    }

    private func deleteScript(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            if url.lastPathComponent == defaultScriptName {
                UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.defaultScriptName)
            }
            loadScripts()
        } catch {
            presentError(title: "Delete Failed", message: error.localizedDescription)
        }
    }

    private func importScript(from fileURL: URL) {
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            defer { DispatchQueue.main.async { self.isBusy = false } }
            do {
                let directory = try self.scriptsDirectory()
                let dest = directory.appendingPathComponent(fileURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: fileURL, to: dest)
                DispatchQueue.main.async {
                    self.loadScripts()
                    self.presentSuccess(title: "Imported", message: fileURL.lastPathComponent)
                }
            } catch {
                DispatchQueue.main.async {
                    self.presentError(title: "Import Failed", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Feedback

    private func presentError(title: String, message: String) {
        alertTitle = title; alertMessage = message
        alertIsSuccess = false; alertVisible = true
    }

    private func presentSuccess(title: String, message: String) {
        alertTitle = title; alertMessage = message
        alertIsSuccess = true; alertVisible = true
    }

    private func copyName(_ url: URL) {
        UIPasteboard.general.string = url.lastPathComponent
        showCopiedToast()
    }

    private func copyPath(_ url: URL) {
        UIPasteboard.general.string = url.path
        showCopiedToast()
    }

    private func showCopiedToast() {
        withAnimation { justCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { justCopied = false }
        }
    }
}

// MARK: - Script content stubs

private let screenshotDemoScript = """
// Screenshot Demo Script
// Attaches to the target, captures a PNG screenshot, and detaches.

function takeScreenshotDemo() {
    log("[ScreenshotDemo] Starting demo");

    const pid = get_pid();
    log(`[ScreenshotDemo] Target PID: ${pid}`);

    const attachResponse = send_command(`vAttach;${pid.toString(16)}`);
    log(`[ScreenshotDemo] attach_response = ${attachResponse}`);

    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const fileName = `screenshot-${timestamp}.png`;
    const savedPath = take_screenshot(fileName);

    if (savedPath && savedPath.length > 0) {
        log(`[ScreenshotDemo] Screenshot saved to ${savedPath}`);
    } else {
        log("[ScreenshotDemo] Device did not report a saved path.");
    }

    const detachResponse = send_command("D");
    log(`[ScreenshotDemo] detach_response = ${detachResponse}`);
    log("[ScreenshotDemo] Demo complete.");
}

takeScreenshotDemo();
"""

private let screenshotCaptureScript = """
// Screenshot Capture Script
// Takes a screenshot without sending any debugserver commands.

function captureScreenshot() {
    log("[ScreenshotCapture] Requesting screenshot without attaching…");
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const fileName = `standalone-${timestamp}.png`;
    const savedPath = take_screenshot(fileName);

    if (savedPath && savedPath.length > 0) {
        log(`[ScreenshotCapture] Screenshot saved to ${savedPath}`);
    } else {
        log("[ScreenshotCapture] Device did not report a saved path.");
    }

    log("[ScreenshotCapture] Done.");
}

captureScreenshot();
"""
