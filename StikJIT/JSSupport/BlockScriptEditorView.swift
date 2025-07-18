import SwiftUI
import Foundation

struct BlockScriptEditorView: View {
    let scriptURL: URL
    @State private var script = BlockScript()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            List {
                ForEach($script.blocks) { $block in
                    BlockRow(block: $block)
                }
                .onDelete { script.blocks.remove(atOffsets: $0) }
                .onMove { script.blocks.move(fromOffsets: $0, toOffset: $1) }
            }
            .toolbar { EditButton() }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    saveScript()
                    dismiss()
                }
            }
            .padding()
        }
        .navigationTitle(scriptURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu("Add Block") {
                    ForEach(BlockType.allCases) { type in
                        Button(type.rawValue) {
                            script.blocks.append(Block(type: type))
                        }
                    }
                }
            }
        }
        .onAppear(perform: loadScript)
    }

    private func loadScript() {
        script = BlockScript.load(from: scriptURL)
    }

    private func saveScript() {
        script.save(to: scriptURL)
        let jsURL = scriptURL.deletingPathExtension().appendingPathExtension("js")
        script.saveAsJS(to: jsURL)
    }
}

struct BlockRow: View {
    @Binding var block: Block

    var body: some View {
        HStack {
            Picker("Type", selection: $block.type) {
                ForEach(BlockType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            TextField("Value", text: $block.value)
        }
    }
}
