//
//  DeviceInfoManager.swift
//  StikDebug
//
//  Created by Stephen on 8/2/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Device Info Manager

struct LockdownClientSendable: @unchecked Sendable {
    let raw: OpaquePointer
}

@MainActor
final class DeviceInfoManager: ObservableObject {
    @Published var entries: [(key: String, value: String)] = []
    @Published var busy = false
    @Published var error: (title: String, message: String)?
    private var initialized = false
    private let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    private var lockdownHandle: LockdownClientSendable? = nil

    func initAndLoad() {
        guard !initialized else { loadInfo(); return }
        busy = true
        Task.detached {
            do {
                try JITEnableContext.shared.ensureHeartbeat()
            } catch {
                await MainActor.run {
                    self.error = ("Initialization Failed", error.localizedDescription)
                    self.busy = false
                }
                return
            }
            do {
                let lockdownHandle = LockdownClientSendable(raw: try JITEnableContext.shared.ideviceInfoInit())

                await MainActor.run {
                    self.lockdownHandle = lockdownHandle
                    self.initialized = true
                    self.loadInfo()
                }
            } catch {
                await MainActor.run {
                    self.error = ("Initialization Failed", error.localizedDescription)
                    self.busy = false
                }
            }

        }
    }

    private func loadInfo() {
        busy = true
        Task.detached {
            var cXml : UnsafeMutablePointer<CChar>? = nil;
            do {
                cXml = try await JITEnableContext.shared.ideviceInfoGetXML(withLockdownClient: self.lockdownHandle?.raw)
            } catch {
                await MainActor.run {
                    self.error = ("Fetch Error", "Failed to fetch device info \(error)")
                    self.busy = false
                }
                return
            }
            guard let cXml else { return }
            
            defer { free(UnsafeMutableRawPointer(mutating: cXml)) }
            guard let xml = String(validatingUTF8: cXml) else {
                await MainActor.run {
                    self.error = ("Parse Error", "Invalid XML data")
                    self.busy = false
                }
                return
            }
            do {
                let data = Data(xml.utf8)
                guard let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                    throw NSError(domain: "DeviceInfo", code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "Expected dictionary"])
                }
                let formatted = dict.keys.sorted().map { ($0, Self.convertToString(dict[$0]!)) }
                await MainActor.run {
                    self.entries = formatted
                    self.busy = false
                }
            } catch {
                await MainActor.run {
                    self.error = ("Parse Error", error.localizedDescription)
                    self.busy = false
                }
            }
        }
    }

    func cleanup() {
        if let lockdownHandle {
            lockdownd_client_free(lockdownHandle.raw)
            self.lockdownHandle = nil
        }

        initialized = false
    }

    nonisolated private static func convertToString(_ raw: Any) -> String {
        switch raw {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        default: return String(describing: raw)
        }
    }

    func exportToCSV() throws -> URL {
        var csv = "Key,Value\n"
        for (k, v) in entries {
            csv += "\"\(k.replacingOccurrences(of: "\"", with: "\"\""))\","
            csv += "\"\(v.replacingOccurrences(of: "\"", with: "\"\""))\"\n"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DeviceInfo.csv")
        try csv.data(using: .utf8)?.write(to: url)
        return url
    }
}

// MARK: - Device Info UI

struct DeviceInfoView: View {
    @StateObject private var mgr = DeviceInfoManager()
    @State private var importer = false
    @State private var exportURL: URL?
    @State private var isShowingExporter = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var justCopied = false

    private let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var pairingURL: URL { docs.appendingPathComponent("pairingFile.plist") }
    private var isPaired: Bool { FileManager.default.fileExists(atPath: pairingURL.path) }

    @State private var searchText = ""
    @State private var alert = false
    @State private var alertTitle = ""
    @State private var alertMsg = ""
    @State private var alertSuccess = false

    var filteredEntries: [(key: String, value: String)] {
        guard !searchText.isEmpty else { return mgr.entries }
        return mgr.entries.filter {
            $0.key.localizedCaseInsensitiveContains(searchText)
            || $0.value.localizedCaseInsensitiveContains(searchText)
        }
    }
    

    var body: some View {
        NavigationStack {
            List {
                if !isPaired {
                    Section {
                        Label("No pairing file detected", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Import your device's pairing file to get started.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !mgr.entries.isEmpty {
                    Section {
                        ForEach(filteredEntries, id: \.key) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.key)
                                    .font(.subheadline.weight(.semibold))
                                Text(entry.value)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 2)
                            .contextMenu {
                                Button { copyToPasteboard(entry.value) } label: {
                                    Label("Copy Value", systemImage: "doc.on.doc")
                                }
                                Button { copyToPasteboard("\(entry.key): \(entry.value)") } label: {
                                    Label("Copy Key & Value", systemImage: "doc.on.clipboard")
                                }
                            }
                        }
                    }
                } else if !mgr.busy && isPaired {
                    Section {
                        Text("No info available").foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search device info…"
            )
            .navigationTitle("Device Info")
            .overlay {
                if mgr.busy {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView("Fetching device info…")
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
            .alert(alertTitle, isPresented: $alert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMsg)
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isPaired {
                        Button { mgr.initAndLoad() } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }

                        Button {
                            do {
                                exportURL = try mgr.exportToCSV()
                                isShowingExporter = true
                            } catch {
                                fail("Export Failed", error.localizedDescription)
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .disabled(mgr.entries.isEmpty)

                        Menu {
                            Button { copyAllText() } label: {
                                Label("Copy All (Text)", systemImage: "doc.on.doc")
                            }
                            Button { copyAllCSV() } label: {
                                Label("Copy All (CSV)", systemImage: "tablecells")
                            }
                            Button { shareAll() } label: {
                                Label("Share…", systemImage: "square.and.arrow.up.on.square")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .disabled(mgr.entries.isEmpty)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isPaired {
                        Button { importer = true } label: {
                            Label("Import Pairing File", systemImage: "doc.badge.plus")
                        }
                    }
                }
            }
            .fileImporter(isPresented: $importer, allowedContentTypes: [.propertyList]) { result in
                if case .success(let url) = result { importPairing(from: url) }
            }
            .fileExporter(
                isPresented: $isShowingExporter,
                document: CSVDocument(url: exportURL),
                contentType: .commaSeparatedText,
                defaultFilename: "DeviceInfo"
            ) { _ in notify("Export Complete", "Device info exported to CSV") }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(items: shareItems)
            }
            .onAppear { if isPaired { mgr.initAndLoad() } }
            .onDisappear { mgr.cleanup() }
            .onChange(of: mgr.error?.message) { _ in
                if let err = mgr.error {
                    fail(err.title, err.message)
                    mgr.error = nil
                }
            }
        }
            }

    // MARK: - Copy / Share helpers

    private func allAsText() -> String {
        filteredEntries.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }

    private func allAsCSV() -> String {
        var csv = "Key,Value\n"
        for (k, v) in filteredEntries {
            let kq = k.replacingOccurrences(of: "\"", with: "\"\"")
            let vq = v.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(kq)\",\"\(vq)\"\n"
        }
        return csv
    }

    private func copyAllText() {
        UIPasteboard.general.string = allAsText()
        hapticCopySuccess()
        showCopiedToast()
    }

    private func copyAllCSV() {
        UIPasteboard.general.string = allAsCSV()
        hapticCopySuccess()
        showCopiedToast()
    }

    private func copyToPasteboard(_ str: String) {
        UIPasteboard.general.string = str
        hapticCopySuccess()
        showCopiedToast()
    }

    private func shareAll() {
        let text = allAsText()
        shareItems = [text]
        showShareSheet = true
    }

    private func hapticCopySuccess() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    private func showCopiedToast() {
        withAnimation { justCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { justCopied = false }
        }
    }

    // MARK: - Pairing Import

    private func importPairing(from src: URL) {
        guard src.startAccessingSecurityScopedResource() else { return }
        defer { src.stopAccessingSecurityScopedResource() }
        do {
            if FileManager.default.fileExists(atPath: pairingURL.path) {
                try FileManager.default.removeItem(at: pairingURL)
            }
            try FileManager.default.copyItem(at: src, to: pairingURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: pairingURL.path)
            notify("Pairing File Added", "Your device is ready. Tap Reload to fetch info.")
            mgr.initAndLoad()
        } catch {
            fail("Import Failed", error.localizedDescription)
        }
    }

    // MARK: - Alerts

    private func fail(_ title: String, _ msg: String) {
        alertTitle = title; alertMsg = msg; alertSuccess = false; alert = true
    }
    private func notify(_ title: String, _ msg: String) {
        alertTitle = title; alertMsg = msg; alertSuccess = true; alert = true
    }
}

// MARK: - CSV Document

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [] }
    static var writableContentTypes: [UTType] { [UTType.commaSeparatedText] }
    let url: URL?
    init(url: URL?) { self.url = url }
    init(configuration: ReadConfiguration) throws { fatalError("Not supported") }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = url else { throw NSError(domain: "CSVDocument", code: -1) }
        return try FileWrapper(url: url, options: .immediate)
    }
}

// MARK: - UIKit Share Sheet wrapper

private struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
