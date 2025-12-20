import Foundation

struct ToolInfo: Decodable {
    struct Capabilities: Decodable {
        let internetAccess: Bool?

        enum CodingKeys: String, CodingKey {
            case internetAccess = "internet_access"
        }
    }

    let author: String
    let desc: String
    let capabilities: Capabilities?
    let requiredIDeviceFunctions: [String]?
    


    enum CodingKeys: String, CodingKey {
        case author
        case desc
        case capabilities
        case requiredIDeviceFunctions = "required_idevice_functions"
    }
}


class MiniToolBundle: ObservableObject, Identifiable {
    static func == (lhs: MiniToolBundle, rhs: MiniToolBundle) -> Bool {
        return lhs.name == rhs.name
    }
    
    @Published var url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    var id: String { url.lastPathComponent }
    var name: String { url.deletingPathExtension().lastPathComponent }
    var indexURL: URL { url.appendingPathComponent("index.html") }
    var backgroundURL: URL { url.appendingPathComponent("background.js") }

    var isValid: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: indexURL.path) && fm.fileExists(atPath: backgroundURL.path)
    }
    
    func getHostName() -> String {
        let d = name.data(using: .utf8)
        let b = d!.base64EncodedString().replacingOccurrences(of:"+", with:"").replacingOccurrences(of:"/", with:"").replacingOccurrences(of:"=", with:"")
        
        return "\(b).stiktool"
    }
}

final class MiniToolStore: ObservableObject {
    @Published private(set) var tools: [MiniToolBundle] = []
    @Published var isBusy: Bool = false
    @Published var lastError: String?

    func refresh() {
        let directory = toolsDirectory()
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let bundles = contents
            .filter { url in
                let ext = url.pathExtension.lowercased()
                return ext == "stiktool" || url.hasDirectoryPath
            }
            .map { MiniToolBundle(url: $0) }
            .filter { $0.isValid }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        DispatchQueue.main.async {
            self.tools = bundles
        }
    }

    func delete(_ tool: MiniToolBundle) {
        do {
            try FileManager.default.removeItem(at: tool.url)
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func importTool(from externalURL: URL) {
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            defer { DispatchQueue.main.async { self.isBusy = false } }
            do {
          let accessing = externalURL.startAccessingSecurityScopedResource()
          defer { if accessing { externalURL.stopAccessingSecurityScopedResource() } }
                let destination = self.toolsDirectory().appendingPathComponent(externalURL.lastPathComponent)
                let fm = FileManager.default
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.copyItem(at: externalURL, to: destination)
                DispatchQueue.main.async { self.refresh() }
            } catch {
                DispatchQueue.main.async { self.lastError = error.localizedDescription }
            }
        }
    }

    func toolsDirectory() -> URL {
        let dir = URL.documentsDirectory.appendingPathComponent("tools", isDirectory: true)
        var isDir: ObjCBool = false
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                try? fm.removeItem(at: dir)
            }
        }
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    static func toolsDataDirectory() -> URL {
        let dir = URL.documentsDirectory.appendingPathComponent("MiniToolData", isDirectory: true)
        var isDir: ObjCBool = false
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                try? fm.removeItem(at: dir)
            }
        }
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func sanitizedToolName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let name = String(filtered).replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
        return name.isEmpty ? "Untitled" : name
    }
}
