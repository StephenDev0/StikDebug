import Foundation

enum BlockType: String, Codable, CaseIterable, Identifiable {
    case sendCommand
    case log

    var id: String { rawValue }
}

struct Block: Codable, Identifiable {
    var id = UUID()
    var type: BlockType = .sendCommand
    var value: String = ""
}

struct BlockScript: Codable {
    var blocks: [Block] = []

    func generateJS() -> String {
        blocks.map { block in
            let escaped = block.value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            switch block.type {
            case .sendCommand:
                return "send_command(\"\(escaped)\")"
            case .log:
                return "log(\"\(escaped)\")"
            }
        }.joined(separator: "\n")
    }

    static func load(from url: URL) -> BlockScript {
        if let data = try? Data(contentsOf: url),
           let script = try? JSONDecoder().decode(BlockScript.self, from: data) {
            return script
        }
        return BlockScript()
    }

    func save(to url: URL) {
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: url)
        }
    }

    func saveAsJS(to url: URL) {
        let js = generateJS()
        try? js.write(to: url, atomically: true, encoding: .utf8)
    }
}
