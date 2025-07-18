import SwiftUI
import Foundation

struct BlockScriptEditorView: View {
    let scriptURL: URL
    @State private var script = BlockScript()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($script.blocks) { $block in
                    BlockRow(block: $block)
                }
                .onDelete { script.blocks.remove(atOffsets: $0) }
                .onMove { script.blocks.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .toolbar { EditButton() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
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
        HStack(spacing: 8) {
            Picker("Type", selection: $block.type) {
                ForEach(BlockType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)

            if !block.type.placeholder.isEmpty {
                TextField(block.type.placeholder, text: $block.value)
                    .textFieldStyle(.roundedBorder)

                if !block.type.options.isEmpty {
                    Menu {
                        ForEach(block.type.options, id: \.self) { option in
                            Button(option) { block.value = option }
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            } else {
                Text(block.type.rawValue)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(block.type.color.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
