//
//  ScriptListView.swift
//  StikDebug
//
//  Created by s s on 2025/7/4.
//

import SwiftUI

struct ScriptListView: View {
    @State private var scripts: [URL] = []
    @State private var selectedScript: URL?
    @State private var navigateToEditor = false
    @State private var showNewFileAlert = false
    @State private var newFileName = ""
    @AppStorage("DefaultScriptName") var defaultScriptName = "attachDetach.js"
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(scripts, id: \.self) { script in
                        NavigationLink {
                            ScriptEditorView(scriptURL: script)
                        } label: {
                            HStack {
                                Text(script.lastPathComponent)
                                    .font(.headline)
                                
                                if(defaultScriptName == script.lastPathComponent) {
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
                } footer: {
                    Text("Swipe left to set a script as the default script. Enable script execution after connecting in settings.")
                }
            }
            .navigationTitle("JavaScript Files")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showNewFileAlert = true
                    }) {
                        Label("New Script", systemImage: "plus")
                    }
                }
            }
            .onAppear(perform: loadScripts)
            .alert("New Script", isPresented: $showNewFileAlert, actions: {
                TextField("Filename", text: $newFileName)
                Button("Create", action: createNewScript)
                Button("Cancel", role: .cancel) {}
            })

        }
    }

    private func scriptsDirectory() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scripts")
        
        var isDir : ObjCBool = false
        var isDirExist = FileManager.default.fileExists(atPath: dir.path(), isDirectory: &isDir)
        
        do {
            if isDirExist && !isDir.boolValue {
                try FileManager.default.removeItem(at: dir)
                isDirExist = false
            }
            
            if !isDirExist {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: Bundle.main.url(forResource: "attachDetach", withExtension: "js")!, to: dir.appendingPathComponent("attachDetach.js"))
            }
        } catch {
            showAlert(title: "Unable to Create Scripts Folder", message: error.localizedDescription, showOk: true)
        }
        return dir
    }

    private func loadScripts() {
        let dir = scriptsDirectory()
        scripts = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "js" } ?? []

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
            showAlert(title: "Failed to Create New Script", message: "A script with the same name already exists.", showOk: true)
            return
        }

        do {
            try "".write(to: newURL, atomically: true, encoding: .utf8)
            newFileName = ""
            loadScripts()
        } catch {
            print("Error creating file: \(error)")
        }
    }

    private func deleteScript(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        if url.lastPathComponent == defaultScriptName {
            UserDefaults.standard.removeObject(forKey: "DefaultScriptName")
        }
        loadScripts()
    }
}
