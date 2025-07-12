//
//  ScriptListView.swift
//  StikDebug
//
//  Created by s s on 2025/7/4.
//

import SwiftUI
import UniformTypeIdentifiers

struct ScriptListView: View {
    @State private var scripts: [URL] = []
    @State private var showNewFileAlert = false
    @State private var newFileName = ""
    @State private var showImporter = false
    @AppStorage("DefaultScriptName") private var defaultScriptName = "attachDetach.js"

    var onSelectScript: ((URL) -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(scripts, id: \.self) { script in
                        if let onSelectScript {
                            Button {
                                onSelectScript(script)
                            } label: {
                                HStack {
                                    Text(script.lastPathComponent)
                                        .font(.headline)
                                    if defaultScriptName == script.lastPathComponent {
                                        Spacer()
                                        Image(systemName: "star.fill")
                                    }
                                }
                            }
                        } else {
                            NavigationLink {
                                ScriptEditorView(scriptURL: script)
                            } label: {
                                HStack {
                                    Text(script.lastPathComponent)
                                        .font(.headline)
                                    if defaultScriptName == script.lastPathComponent {
                                        Spacer()
                                        Image(systemName: "star.fill")
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteScript(script)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    saveDefaultScript(script)
                                } label: {
                                    Label("Set Default", systemImage: "star")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                } footer: {
                    Text("Swipe left to set a script as the default. Enable script execution after connecting in settings.")
                }
            }
            .navigationTitle("JavaScript Files")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewFileAlert = true
                    } label: {
                        Label("New Script", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import", systemImage: "tray.and.arrow.down")
                    }
                }
            }
            .onAppear(perform: loadScripts)
            .alert("New Script", isPresented: $showNewFileAlert) {
                TextField("Filename", text: $newFileName)
                Button("Create", action: createNewScript)
                Button("Cancel", role: .cancel) { }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType(filenameExtension: "js") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let fileURL = urls.first {
                        do {
                            let dest = scriptsDirectory().appendingPathComponent(fileURL.lastPathComponent)
                            if FileManager.default.fileExists(atPath: dest.path) {
                                try FileManager.default.removeItem(at: dest)
                            }
                            try FileManager.default.copyItem(at: fileURL, to: dest)
                            loadScripts()
                        } catch {
                            print("Import failed:", error)
                        }
                    }
                case .failure(let error):
                    print("File import error:", error)
                }
            }
        }
    }
        
    private func scriptsDirectory() -> URL {
        let dir = FileManager
            .default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scripts")
        
        var isDir: ObjCBool = false
        var exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir)
        
        do {
            if exists && !isDir.boolValue {
                try FileManager.default.removeItem(at: dir)
                exists = false
            }
            if !exists {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                if let bundleURL = Bundle.main.url(forResource: "attachDetach", withExtension: "js") {
                    try FileManager.default.copyItem(
                        at: bundleURL,
                        to: dir.appendingPathComponent("attachDetach.js")
                    )
                }
            }
        } catch {
            showAlert(title: "Unable to Create Scripts Folder",
                      message: error.localizedDescription,
                      showOk: true)
        }
        
        return dir
    }
    
    private func loadScripts() {
        let dir = scriptsDirectory()
        scripts = (try? FileManager
            .default
            .contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "js" } ?? []
    }
    
    private func saveDefaultScript(_ url: URL) {
        defaultScriptName = url.lastPathComponent
    }
    
    private func createNewScript() {
        guard !newFileName.isEmpty else { return }
        var filename = newFileName
        if !filename.hasSuffix(".js") {
            filename += ".js"
        }
        let newURL = scriptsDirectory().appendingPathComponent(filename)
        
        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            showAlert(title: "Failed to Create New Script",
                      message: "A script with the same name already exists.",
                      showOk: true)
            return
        }
        
        do {
            try "".write(to: newURL, atomically: true, encoding: .utf8)
            newFileName = ""
            loadScripts()
        } catch {
            print("Error creating file:", error)
        }
    }
    
    private func deleteScript(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            if url.lastPathComponent == defaultScriptName {
                UserDefaults.standard.removeObject(forKey: "DefaultScriptName")
            }
            loadScripts()
        } catch {
            print("Error deleting script:", error)
        }
    }
}
