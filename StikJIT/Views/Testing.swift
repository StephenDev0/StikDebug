//
//  Testing.swift
//  StikDebug
//
//  Created by Stephen Bove on 8/8/25.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import ZIPFoundation
import ZSign
import StikImporter
import UIKit
import PhotosUI

// MARK: - C bridge

@_silgen_name("install_ipa")
private func c_install_ipa(
    _ ip: UnsafePointer<CChar>,
    _ pairing: UnsafePointer<CChar>,
    _ udid: UnsafePointer<CChar>?,
    _ ipa: UnsafePointer<CChar>
) -> Int32

private func installErrorMessage(_ code: Int32) -> String {
    switch code {
    case 0:  return "Success"
    case 1:  return "Pairing file unreadable"
    case 2:  return "TCP provider error"
    case 3:  return "AFC connect error"
    case 4:  return "IPA unreadable"
    case 5:  return "AFC open error"
    case 6:  return "AFC write error"
    case 7:  return "Install-proxy error"
    case 8:  return "Device refused IPA"
    case 9:  return "Invalid IP address"
    default: return "Unknown (\(code))"
    }
}

// MARK: - Files

private let docs      = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
private let appsJSON  = docs.appendingPathComponent("signed_apps.json")
private let certsJSON = docs.appendingPathComponent("certs.json")
// Repos disabled for now
// private let reposJSON = docs.appendingPathComponent("repos.json")

// MARK: - Models

struct SignedApp: Identifiable, Codable, Hashable {
    let id:       UUID
    let name:     String
    let bundleID: String
    let version:  String
    let ipaPath:  String
    let iconPath: String?
    
    var ipaURL:  URL { docs.appendingPathComponent(ipaPath) }
    var iconURL: URL? { iconPath.map { docs.appendingPathComponent($0) } }
}

struct Certificate: Identifiable, Codable, Hashable {
    let id:      UUID
    let name:    String
    let p12Path: String
    let mobPath: String?
    
    var p12URL: URL { docs.appendingPathComponent(p12Path) }
    var mobURL: URL? { mobPath.map { docs.appendingPathComponent($0) } }
}

// MARK: - FS helpers

private enum FSX {
    static func mkdir(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url,
                                                    withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o755])
        }
    }
    static func copySecure(from src: URL, to dst: URL) throws {
        let ok = src.startAccessingSecurityScopedResource()
        defer { if ok { src.stopAccessingSecurityScopedResource() } }
        if FileManager.default.fileExists(atPath: dst.path) { try FileManager.default.removeItem(at: dst) }
        try FileManager.default.copyItem(at: src, to: dst)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: dst.path)
    }
    static func perms(app: URL) throws {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isExecutableKey]
        guard let e = FileManager.default.enumerator(at: app, includingPropertiesForKeys: keys) else { return }
        for case let f as URL in e {
            let rv = try f.resourceValues(forKeys: Set(keys))
            if rv.isDirectory == true {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: f.path)
            } else {
                let exec = rv.isExecutable == true ||
                           f.lastPathComponent == app.lastPathComponent.replacingOccurrences(of: ".app", with: "") ||
                           (f.pathExtension.isEmpty && !f.lastPathComponent.contains("."))
                try FileManager.default.setAttributes([.posixPermissions: exec ? 0o755 : 0o644],
                                                      ofItemAtPath: f.path)
            }
        }
    }
}

// MARK: - App Signer Manager

@MainActor
final class AppSignerManager: ObservableObject {
    private var didFinishInitialLoad = false
    
    @Published var apps: [SignedApp] = [] {
        didSet { if didFinishInitialLoad { saveApps() } }
    }
    @Published var certs: [Certificate] = [] {
        didSet { if didFinishInitialLoad { saveCerts() } }
    }
    @Published var selectedCertID: UUID?
    @Published var busy   = false
    @Published var ipaURL: URL?
    @Published var ipaName: String?
    
    /// Parsed from the IPA (for reference)
    @Published var detectedName: String?
    @Published var detectedBundleID: String?
    @Published var detectedVersion: String?
    
    /// Advanced overrides (used if non-empty; bundleId only if `useCustomBundleID`)
    @Published var advName: String = ""
    @Published var advBundleID: String = ""
    @Published var advVersion: String = ""
    @Published var useCustomBundleID: Bool = false
    
    /// Advanced icon overrides
    @Published var useCustomIcon: Bool = false
    @Published var advIconURL: URL?
    
    let imports     = docs.appendingPathComponent("Imports", isDirectory: true)
    let certsFolder = docs.appendingPathComponent("Certs",   isDirectory: true)
    
    init() {
        try? FSX.mkdir(imports)
        try? FSX.mkdir(certsFolder)
        migrateAndLoadApps()
        migrateAndLoadCerts()
        didFinishInitialLoad = true
    }
    
    private func migrateAndLoadApps() {
        guard let data = try? Data(contentsOf: appsJSON),
              let stored = try? JSONDecoder().decode([SignedApp].self, from: data) else { return }
        
        var fixed: [SignedApp] = []
        for app in stored {
            if FileManager.default.fileExists(atPath: app.ipaURL.path) {
                fixed.append(app)
                continue
            }
            let expectedRel = "SignedApps/\(app.name)/\(app.name).ipa"
            let newAbs      = docs.appendingPathComponent(expectedRel).path
            if FileManager.default.fileExists(atPath: newAbs) {
                let newIconRel = "SignedApps/\(app.name)/icon.png"
                fixed.append(SignedApp(
                    id: app.id, name: app.name, bundleID: app.bundleID,
                    version: app.version, ipaPath: expectedRel,
                    iconPath: FileManager.default.fileExists(atPath: docs.appendingPathComponent(newIconRel).path) ? newIconRel : nil))
            }
        }
        apps = fixed
    }
    private func saveApps() {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        try? data.write(to: appsJSON)
    }
    
    private func migrateAndLoadCerts() {
        guard let data = try? Data(contentsOf: certsJSON),
              let stored = try? JSONDecoder().decode([Certificate].self, from: data) else { return }
        
        var fixed: [Certificate] = []
        for cert in stored {
            if FileManager.default.fileExists(atPath: cert.p12URL.path) &&
               (cert.mobURL == nil || FileManager.default.fileExists(atPath: cert.mobURL!.path)) {
                fixed.append(cert)
                continue
            }
            let dir = certsFolder.appendingPathComponent(cert.id.uuidString)
            let newP12Rel = "Certs/\(cert.id.uuidString)/cert.p12"
            let newMobRel = "Certs/\(cert.id.uuidString)/profile.mobileprovision"
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("cert.p12").path) {
                fixed.append(Certificate(
                    id: cert.id, name: cert.name,
                    p12Path: newP12Rel,
                    mobPath: FileManager.default.fileExists(atPath: dir.appendingPathComponent("profile.mobileprovision").path) ? newMobRel : nil))
            }
        }
        certs = fixed
        if selectedCertID == nil { selectedCertID = certs.first?.id }
    }
    private func saveCerts() {
        guard let data = try? JSONEncoder().encode(certs) else { return }
        try? data.write(to: certsJSON)
    }
    
    func deleteApp(_ app: SignedApp) {
        if let idx = apps.firstIndex(of: app) {
            try? FileManager.default.removeItem(at: app.ipaURL.deletingLastPathComponent())
            apps.remove(at: idx)
        }
    }
    
    func deleteCert(_ cert: Certificate) {
        let dir = certsFolder.appendingPathComponent(cert.id.uuidString)
        try? FileManager.default.removeItem(at: dir)
        KeychainHelper.shared.deletePassword(forKey: cert.id.uuidString)
        certs.removeAll { $0.id == cert.id }
        if selectedCertID == cert.id { selectedCertID = certs.first?.id }
        saveCerts()
    }
    
    func importIPA(from url: URL) throws {
        let dst = imports.appendingPathComponent("current.ipa")
        try FSX.copySecure(from: url, to: dst)
        ipaURL = dst
        ipaName = try parseIPAName(at: dst)
        try? parseIPAMetadata(at: dst)
    }
    func importIPAFromDownloads(_ localURL: URL) throws {
        let dst = imports.appendingPathComponent("current.ipa")
        if FileManager.default.fileExists(atPath: dst.path) { try FileManager.default.removeItem(at: dst) }
        try FileManager.default.copyItem(at: localURL, to: dst)
        ipaURL = dst
        ipaName = try? parseIPAName(at: dst)
        try? parseIPAMetadata(at: dst)
    }
    
    private func parseIPAName(at ipa: URL) throws -> String? {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FSX.mkdir(tmp)
        try FileManager.default.unzipItem(at: ipa, to: tmp)
        let payload = tmp.appendingPathComponent("Payload")
        let appDir = try FileManager.default.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
            .first { $0.pathExtension == "app" }
        defer { try? FileManager.default.removeItem(at: tmp) }
        guard let dir = appDir,
              let dict = NSDictionary(contentsOf: dir.appendingPathComponent("Info.plist")) else { return nil }
        return (dict["CFBundleDisplayName"] ?? dict["CFBundleName"]) as? String
    }
    
    private func parseIPAMetadata(at ipa: URL) throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FSX.mkdir(tmp)
        try FileManager.default.unzipItem(at: ipa, to: tmp)
        let payload = tmp.appendingPathComponent("Payload")
        let appDir = try FileManager.default.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
            .first { $0.pathExtension == "app" }
        defer { try? FileManager.default.removeItem(at: tmp) }
        guard let dir = appDir,
              let dict = NSDictionary(contentsOf: dir.appendingPathComponent("Info.plist")) as? [String: Any] else { return }
        detectedName      = (dict["CFBundleDisplayName"] ?? dict["CFBundleName"]) as? String
        detectedBundleID  = dict["CFBundleIdentifier"] as? String
        detectedVersion   = dict["CFBundleShortVersionString"] as? String
    }
    
    func addCertificate(name: String, p12: URL, mob: URL, password: String,
                        onErr: (String,String)->Void, onOK: (String,String)->Void) {
        let id  = UUID()
        let dir = certsFolder.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            try FSX.mkdir(dir)
            try FSX.copySecure(from: p12, to: dir.appendingPathComponent("cert.p12"))
            try FSX.copySecure(from: mob, to: dir.appendingPathComponent("profile.mobileprovision"))
            KeychainHelper.shared.save(password: password, forKey: id.uuidString)
            
            certs.append(Certificate(
                id: id, name: name,
                p12Path: "Certs/\(id.uuidString)/cert.p12",
                mobPath: "Certs/\(id.uuidString)/profile.mobileprovision"))
            selectedCertID = id
            onOK("Certificate added", name)
        } catch { onErr("Cert error", error.localizedDescription) }
    }
    
    func signIPA(onErr: @escaping (String,String)->Void,
                 onOK:  @escaping (String,String)->Void) {
        guard !busy else { return }
        guard let ipa = ipaURL,
              let cert = certs.first(where: { $0.id == selectedCertID }) else {
            onErr("Missing data", "Import IPA and select certificate first"); return
        }
        busy = true
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FSX.mkdir(tmp)
                _ = ipa.startAccessingSecurityScopedResource(); defer { ipa.stopAccessingSecurityScopedResource() }
                
                try FileManager.default.unzipItem(at: ipa, to: tmp)
                let payload = tmp.appendingPathComponent("Payload")
                guard let appFolder = try FileManager.default.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
                        .first(where: { $0.pathExtension == "app" }) else {
                    throw NSError(domain: "Signer", code: 1, userInfo: [NSLocalizedDescriptionKey: "No .app found"])
                }
                try FSX.perms(app: appFolder)
                
                let plistURL = appFolder.appendingPathComponent("Info.plist")
                guard
                    let dict   = NSDictionary(contentsOf: plistURL) as? [String: Any],
                    let curName   = (dict["CFBundleDisplayName"] ?? dict["CFBundleName"]) as? String,
                    let curBundle = dict["CFBundleIdentifier"]         as? String,
                    let curVer    = dict["CFBundleShortVersionString"] as? String
                else {
                    throw NSError(domain: "Signer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Info.plist parse error"])
                }
                
                // Capture advanced fields on MainActor
                var trimmedName: String = ""
                var trimmedBID: String = ""
                var trimmedVer: String = ""
                var useCustomBID: Bool = false
                var useCustomIcon: Bool = false
                var pickedIconURL: URL?
                await MainActor.run {
                    trimmedName    = self.advName.trimmingCharacters(in: .whitespacesAndNewlines)
                    trimmedBID     = self.advBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                    trimmedVer     = self.advVersion.trimmingCharacters(in: .whitespacesAndNewlines)
                    useCustomBID   = self.useCustomBundleID
                    useCustomIcon  = self.useCustomIcon
                    pickedIconURL  = self.advIconURL
                }
                
                let newName   = trimmedName.isEmpty ? curName : trimmedName
                let newBundle = (useCustomBID && !trimmedBID.isEmpty) ? trimmedBID : curBundle
                let newVer    = trimmedVer.isEmpty ? curVer : trimmedVer
                
                // Write overrides into Info.plist BEFORE signing
                if let m = NSMutableDictionary(contentsOf: plistURL) {
                    m["CFBundleDisplayName"] = newName
                    m["CFBundleName"] = newName
                    m["CFBundleShortVersionString"] = newVer
                    m["CFBundleIdentifier"] = newBundle
                    m.write(to: plistURL, atomically: true)
                }
                
                // If requested, generate a full icon set and update CFBundleIcons
                if useCustomIcon, let url = pickedIconURL,
                   let img = UIImage(contentsOfFile: url.path) {
                    let icon1024URL = try await self.writeIconSet(image: img, into: appFolder)
                    if let m = NSMutableDictionary(contentsOf: plistURL) {
                        let primary: [String: Any] = [
                            "CFBundleIconFiles": ["AppIcon20", "AppIcon29", "AppIcon40", "AppIcon60", "AppIcon76", "AppIcon83.5"]
                        ]
                        m["CFBundleIcons"] = ["CFBundlePrimaryIcon": primary]
                        m.write(to: plistURL, atomically: true)
                    }
                    // Provide a preview fallback for our UI list
                    let previewDest = appFolder.appendingPathComponent("icon.png")
                    try? FileManager.default.removeItem(at: previewDest)
                    try? FileManager.default.copyItem(at: icon1024URL, to: previewDest)
                }
                
                let pw = KeychainHelper.shared.readPassword(forKey: cert.id.uuidString) ?? ""
                let rc = zsign(
                    appFolder.path,
                    cert.p12URL.path,
                    cert.p12URL.path,
                    cert.mobURL?.path ?? "",
                    pw
                )
                guard rc == 0 else {
                    throw NSError(domain: "zsign", code: Int(rc),
                                  userInfo: [NSLocalizedDescriptionKey: "zsign returned \(rc)"])
                }
                
                let outDir = docs.appendingPathComponent("SignedApps/\(newName)", isDirectory: true)
                if FileManager.default.fileExists(atPath: outDir.path) { try FileManager.default.removeItem(at: outDir) }
                try FSX.mkdir(outDir)
                try FileManager.default.zipItem(at: payload,
                                                to: outDir.appendingPathComponent("\(newName).ipa"),
                                                shouldKeepParent: true)
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: outDir.appendingPathComponent("\(newName).ipa").path)
                
                var iconRel: String?
                if let iconURL = try? FileManager.default.contentsOfDirectory(at: appFolder, includingPropertiesForKeys: nil)
                    .first(where: { $0.lastPathComponent.lowercased().contains("appicon") && $0.pathExtension == "png" }) {
                    let dst = outDir.appendingPathComponent("icon.png")
                    try? FileManager.default.copyItem(at: iconURL, to: dst)
                    iconRel = "SignedApps/\(newName)/icon.png"
                } else if FileManager.default.fileExists(atPath: appFolder.appendingPathComponent("icon.png").path) {
                    let dst = outDir.appendingPathComponent("icon.png")
                    try? FileManager.default.copyItem(at: appFolder.appendingPathComponent("icon.png"), to: dst)
                    iconRel = "SignedApps/\(newName)/icon.png"
                }
                
                let relIPA = "SignedApps/\(newName)/\(newName).ipa"
                let newApp = SignedApp(
                    id: UUID(), name: newName, bundleID: newBundle,
                    version: newVer, ipaPath: relIPA, iconPath: iconRel)
                
                await MainActor.run {
                    self.apps.removeAll { $0.name == newApp.name }
                    self.apps.append(newApp)
                    self.busy = false
                    onOK("\(newName) is ready for testing", "Saved to \(relIPA)")
                }
            } catch {
                await MainActor.run {
                    self.busy = false
                    onErr("Sign error", error.localizedDescription)
                }
            }
        }
    }
    
    func install(app: SignedApp, ip: String, pairing: String,
                 onErr: @escaping (String,String)->Void,
                 onOK:  @escaping (String,String)->Void) {
        guard !busy else { return }
        guard FileManager.default.fileExists(atPath: app.ipaURL.path) else { onErr("IPA missing", app.ipaURL.path); return }
        guard FileManager.default.fileExists(atPath: pairing) else { onErr("Pairing missing", pairing); return }
        busy = true
        Task.detached { [weak self] in
            guard let self else { return }
            let rc = ip.withCString { ipPtr in
                pairing.withCString { pairPtr in
                    app.ipaURL.path.withCString { ipaPtr in
                        c_install_ipa(ipPtr, pairPtr, nil, ipaPtr)
                    }
                }
            }
            await MainActor.run {
                self.busy = false
                rc == 0 ? onOK("Installed for testing", app.name)
                        : onErr("Install failed", installErrorMessage(rc))
            }
        }
    }
    
    // MARK: - Icon writer helpers
    
    /// Writes all required icon PNGs into `appFolder` and returns the 1024px icon path.
    private func writeIconSet(image: UIImage, into appFolder: URL) throws -> URL {
        typealias IconOut = (px: CGFloat, suffix: String)
        struct IconSpec { let base: String; let outs: [IconOut] }
        let specs: [IconSpec] = [
            IconSpec(base: "AppIcon20",   outs: [(40,"@2x"), (60,"@3x")]),
            IconSpec(base: "AppIcon29",   outs: [(58,"@2x"), (87,"@3x")]),
            IconSpec(base: "AppIcon40",   outs: [(80,"@2x"), (120,"@3x")]),
            IconSpec(base: "AppIcon60",   outs: [(120,"@2x"), (180,"@3x")]),
            IconSpec(base: "AppIcon76",   outs: [(76,""), (152,"@2x")]),
            IconSpec(base: "AppIcon83.5", outs: [(167,"@2x")])
        ]
        for spec in specs {
            for out in spec.outs {
                let file = "\(spec.base)\(out.suffix).png"
                let url = appFolder.appendingPathComponent(file)
                if let data = pngData(from: image, side: out.px) {
                    try data.write(to: url, options: .atomic)
                    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
                }
            }
        }
        // 1024 marketing icon for previews
        let icon1024 = appFolder.appendingPathComponent("AppIcon-1024.png")
        if let data = pngData(from: image, side: 1024) {
            try data.write(to: icon1024, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: icon1024.path)
        }
        return icon1024
    }
    
    private func pngData(from image: UIImage, side: CGFloat) -> Data? {
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.pngData { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// Reusable MaterialCard matching SettingsView.materialCard styling
struct MaterialCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

struct GlassCapsuleButtonStyle: ButtonStyle {
    var minWidth: CGFloat? = nil
    var height: CGFloat = 40
    var strokeOpacity: Double = 0.16
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: minWidth)
            .frame(height: height)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(strokeOpacity), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    var size: CGFloat = 40
    var strokeOpacity: Double = 0.14
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(strokeOpacity), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Custom glassy tab switcher (Repos disabled; only Testing)

enum ManagerSection: String, CaseIterable, Identifiable {
    case testing = "Testing"
    // case repos   = "Repos"
    var id: String { rawValue }
}

// MARK: - Liquid Glass Tab Switcher

struct GlassLiquidTabSwitcher: View {
    @Binding var selection: ManagerSection
    var accent: Color = .white
    var height: CGFloat = 56
    
    private let pad: CGFloat = 6
    private let pillInset: CGFloat = 4
    private let stretchMax: CGFloat = 0.18
    
    @GestureState private var dragX: CGFloat? = nil
    @State private var isDragging = false
    @State private var lastIndex: Int = 0
    
    private var items: [ManagerSection] { [.testing] } // only testing
    
    var body: some View {
        // Hidden per request (testing-repo selector off)
        EmptyView()
    }
    
    private func clamp<T: Comparable>(_ v: T, min lo: T, max hi: T) -> T {
        Swift.max(lo, Swift.min(v, hi))
    }
}

// MARK: - Reusable full-width glass row

private struct GlassInputRow: View {
    let leadingIcon: String
    let title: String
    let statusIcon: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: leadingIcon).imageScale(.medium)
                Text(title).font(.body).lineLimit(1).truncationMode(.tail)
                Spacer()
                if let si = statusIcon { Image(systemName: si).imageScale(.medium) }
                Image(systemName: "chevron.right").imageScale(.medium).opacity(0.8)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Certificate picker sheet

private struct CertPickerSheet: View {
    let certs: [Certificate]
    @Binding var selectedID: UUID?
    var onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Certificates") {
                    ForEach(certs) { cert in
                        HStack {
                            Image(systemName: "checkmark.seal").foregroundStyle(.secondary)
                            Text(cert.name)
                            Spacer()
                            if selectedID == cert.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedID = cert.id; dismiss() }
                    }
                    Button {
                        dismiss()
                        onAdd()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Certificate")
                        }
                    }
                }
            }
            .navigationTitle("Choose Certificate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Manage Certificates (delete)

private struct ManageCertsView: View {
    @Binding var certs: [Certificate]
    @Binding var selected: UUID?
    var onDelete: (Certificate) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(certs) { cert in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(cert.name).font(.body)
                            Text(cert.id.uuidString).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selected == cert.id {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selected = cert.id }
                }
                .onDelete { idx in
                    for i in idx {
                        let c = certs[i]
                        onDelete(c)
                    }
                }
            }
            .navigationTitle("Certificates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Top-level view (Repos disabled)

struct IPAAppManagerView: View {
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.themeExpansionManager) private var themeExpansion

    private var accentColor: Color {
        themeExpansion?.resolvedAccentColor(from: customAccentColorHex) ?? .blue
    }
    private var backgroundStyle: BackgroundStyle {
        themeExpansion?.backgroundStyle(for: appThemeRaw) ?? AppTheme.system.backgroundStyle
    }
    private var preferredScheme: ColorScheme? {
        themeExpansion?.preferredColorScheme(for: appThemeRaw)
    }
    
    @StateObject private var mgr = AppSignerManager()
    
    @State private var pickerShown  = false
    @State private var showAddCert  = false
    @State private var showManageCerts = false
    @State private var showCertPickerSheet = false
    
    // CustomErrorView overlay state
    @State private var alertVisible = false
    @State private var alertTitle   = ""
    @State private var alertMsg     = ""
    @State private var alertType: MessageType = .info
    
    @AppStorage("deviceIP") private var deviceIP = "10.7.0.2"
    private var pairingPath: String { docs.appendingPathComponent("pairingFile.plist").path }
    
    @State private var section: ManagerSection = .testing
    
    // For auto-scroll to “Prepare for testing”
    @State private var scrollProxy: ScrollViewProxy?
    private let signCardAnchor = "signCardAnchor"
    
    // Advanced options UI state
    @State private var showAdvanced = false
    @State private var pickIcon = false
    @State private var photoItem: PhotosPickerItem? = nil   // Photos picker
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground(style: backgroundStyle)
                    .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Selector hidden per request
                            // GlassLiquidTabSwitcher(selection: $section)
                            
                            // Only Testing section
                            signCard.id(signCardAnchor)
                            appsCard
                            versionInfo
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .onAppear { scrollProxy = proxy }
                }
                
                if mgr.busy {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView()
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.20), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.20), radius: 20, x: 0, y: 10)
                }
                
                if alertVisible {
                    CustomErrorView(
                        title: alertTitle,
                        message: alertMsg,
                        onDismiss: { alertVisible = false },
                        showButton: true,
                        primaryButtonText: "OK",
                        messageType: alertType
                    )
                }
            }
            // Show nav bar title again
            .navigationTitle("Testing")
            .navigationBarTitleDisplayMode(.large)
            .stikImporter(isPresented: $pickerShown,
                          selectedURLs: .constant([]),
                          allowedContentTypes: [.item],
                          allowsMultipleSelection: false) { urls in
                if let u = urls.first {
                    do {
                        try mgr.importIPA(from: u)
                        notify("File imported", "File saved to Imports")
                        jumpToSigning()
                    } catch {
                        fail("Import error", error.localizedDescription)
                    }
                }
            }
            .sheet(isPresented: $showAddCert) {
                AddCertView(accent: accentColor) { n, p12, mob, pw in
                    mgr.addCertificate(name: n, p12: p12, mob: mob, password: pw,
                                       onErr: fail, onOK: notify)
                }
            }
            .sheet(isPresented: $showManageCerts) {
                ManageCertsView(certs: $mgr.certs,
                                selected: $mgr.selectedCertID,
                                onDelete: { cert in mgr.deleteCert(cert) })
            }
            .tint(accentColor)
            .preferredColorScheme(preferredScheme)
            // Photos picker → temp PNG saved → advIconURL
            .onChange(of: photoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let img = UIImage(data: data),
                       let png = img.pngData() {

                        let url = FileManager.default.temporaryDirectory
                            .appendingPathComponent("custom-icon-\(UUID().uuidString).png")
                        do {
                            try png.write(to: url, options: .atomic)
                            await MainActor.run { mgr.advIconURL = url }
                        } catch {
                            await MainActor.run { fail("Icon error", error.localizedDescription) }
                        }

                    } else if let fileURL = try? await newItem.loadTransferable(type: URL.self) {
                        do {
                            let data = try Data(contentsOf: fileURL)
                            if let img = UIImage(data: data),
                               let png = img.pngData() {

                                let url = FileManager.default.temporaryDirectory
                                    .appendingPathComponent("custom-icon-\(UUID().uuidString).png")
                                try png.write(to: url, options: .atomic)
                                await MainActor.run { mgr.advIconURL = url }
                            } else {
                                await MainActor.run { fail("Icon error", "Could not decode image data") }
                            }
                        } catch {
                            await MainActor.run { fail("Icon error", error.localizedDescription) }
                        }

                    } else {
                        await MainActor.run { fail("Icon error", "Unsupported photo representation") }
                    }
                }
            }
        }
    }
    
    // MARK: - Testing UI
    
    private var selectedCertName: String {
        mgr.certs.first(where: { $0.id == mgr.selectedCertID })?.name ?? "Select certificate"
    }
    
    private var signCard: some View {
        MaterialCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Prepare for testing")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                
                // Certificate
                GlassInputRow(
                    leadingIcon: "checkmark.seal.fill",
                    title: selectedCertName,
                    statusIcon: mgr.selectedCertID == nil ? nil : "checkmark.circle.fill"
                ) { showCertPickerSheet.toggle() }
                .sheet(isPresented: $showCertPickerSheet) {
                    CertPickerSheet(
                        certs: mgr.certs,
                        selectedID: $mgr.selectedCertID,
                        onAdd: { showAddCert = true }
                    )
                }
                
                // IPA file
                GlassInputRow(
                    leadingIcon: "arrow.down.doc",
                    title: mgr.ipaName ?? ".IPA File",
                    statusIcon: mgr.ipaURL == nil ? nil : "checkmark.circle.fill"
                ) { pickerShown = true }
                
                // Advanced Options
                DisclosureGroup(isExpanded: $showAdvanced) {
                    VStack(spacing: 10) {
                        TextField("", text: $mgr.advName, prompt: Text("Custom app name"))
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.14), lineWidth: 1))
                        
                        Toggle(isOn: $mgr.useCustomBundleID) { Text("Use custom bundle ID") }
                            .toggleStyle(.switch)
                        
                        TextField("", text: $mgr.advBundleID, prompt: Text("Custom bundle ID"))
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.14), lineWidth: 1))
                            .disabled(!mgr.useCustomBundleID)
                            .opacity(mgr.useCustomBundleID ? 1 : 0.5)
                        
                        TextField("", text: $mgr.advVersion, prompt: Text("Custom version"))
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.numbersAndPunctuation)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.14), lineWidth: 1))
                        
                        Toggle(isOn: $mgr.useCustomIcon) { Text("Use custom app icon") }
                            .toggleStyle(.switch)
                        
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text(mgr.advIconURL == nil ? "Choose from Photos…" : "Photo selected")
                                Spacer()
                                Image(systemName: mgr.advIconURL == nil ? "chevron.right" : "checkmark.circle.fill")
                                    .imageScale(.medium)
                            }
                        }
                        .buttonStyle(GlassCapsuleButtonStyle(minWidth: nil, height: 40))
                        .disabled(!mgr.useCustomIcon)
                        .opacity(mgr.useCustomIcon ? 1 : 0.5)
                        
                        Button {
                            pickIcon = true
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                Text("Choose PNG from Files…")
                                Spacer()
                                Image(systemName: "chevron.right").imageScale(.medium)
                            }
                        }
                        .buttonStyle(GlassCapsuleButtonStyle(minWidth: nil, height: 40))
                        .disabled(!mgr.useCustomIcon)
                        .opacity(mgr.useCustomIcon ? 1 : 0.5)
                        .stikImporter(
                            isPresented: $pickIcon,
                            selectedURLs: .constant([]),
                            allowedContentTypes: [UTType.png],
                            allowsMultipleSelection: false
                        ) { urls in
                            mgr.advIconURL = urls.first
                        }
                        
                        Text("Note: The provisioning profile must match the bundle ID. If not, signing will fail.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(.top, 8)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Advanced Options")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .padding(.top, 2)
                
                Button("Prepare") { mgr.signIPA(onErr: fail, onOK: notify) }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
                    .foregroundColor(accentColor.contrastText())
                    // Removed glow/shadow from the Prepare button
                    .disabled(mgr.busy || mgr.ipaURL == nil || mgr.selectedCertID == nil)
            }
            .padding(8)
        }
    }
    
    private var appsCard: some View {
        MaterialCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ready to test apps")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if mgr.apps.isEmpty {
                    // Full-width placeholder matching card content width
                    HStack(spacing: 12) {
                        Image(systemName: "app.dashed")
                            .imageScale(.medium)
                            .foregroundStyle(.secondary)
                        Text("No ready to test apps yet")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                } else {
                    ForEach(mgr.apps) { app in
                        HStack(spacing: 12) {
                            if let img = app.iconURL.flatMap({ UIImage(contentsOfFile: $0.path) }) {
                                Image(uiImage: img)
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(.white.opacity(0.15), lineWidth: 0.5)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(.white.opacity(0.12), lineWidth: 0.5))
                                    .frame(width: 44, height: 44)
                                    .overlay(Image(systemName: "app.fill").opacity(0.6))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name).bold()
                                Text("v\(app.version) • \(app.bundleID)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Test") {
                                mgr.install(app: app, ip: deviceIP, pairing: pairingPath,
                                            onErr: fail, onOK: notify)
                            }
                            .buttonStyle(GlassCapsuleButtonStyle(minWidth: 72, height: 40, strokeOpacity: 0.18))
                            .disabled(mgr.busy)
                            
                            Button(role: .destructive) { mgr.deleteApp(app) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(GlassIconButtonStyle())
                        }
                        .padding(.vertical, 6)
                        Divider().opacity(0.25)
                    }
                }
            }
            .padding(8)
        }
    }
    
    private var versionInfo: some View {
        HStack {
            Spacer()
            Text("iOS \(UIDevice.current.systemVersion)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 6)
    }
    
    // MARK: - Helpers (CustomErrorView)

    private func fail(_ title: String, _ msg: String) {
        alertTitle = title
        alertMsg = msg
        alertType = .error
        alertVisible = true
    }
    private func notify(_ title: String, _ msg: String) {
        alertTitle = title
        alertMsg = msg
        alertType = .success
        alertVisible = true
    }
    private func jumpToSigning() {
        withAnimation(.easeInOut) {
            section = .testing
            scrollProxy?.scrollTo(signCardAnchor, anchor: .top)
        }
    }
}

// MARK: - Add Certificate sheet

private struct AddCertView: View {
    let accent: Color
    var onSave: (String, URL, URL, String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name    = ""
    @State private var p12URL: URL?
    @State private var mobURL: URL?
    @State private var password = ""
    
    @State private var pickP12 = false
    @State private var pickMob = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Certificate name", text: $name)
                    importRow(label: ".mobileprovision", picked: mobURL != nil) { pickMob = true }
                        .stikImporter(isPresented: $pickMob,
                                      selectedURLs: .constant([]),
                                      allowedContentTypes: [UTType.item],
                                      allowsMultipleSelection: false) { mobURL = $0.first }
                    importRow(label: ".p12 file", picked: p12URL != nil) { pickP12 = true }
                        .stikImporter(isPresented: $pickP12,
                                      selectedURLs: .constant([]),
                                      allowedContentTypes: [UTType.item],
                                      allowsMultipleSelection: false) { p12URL = $0.first }
                    SecureField("p12 password", text: $password)
                }
            }
            .navigationTitle("New Certificate")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let p = p12URL, let m = mobURL, !name.isEmpty {
                            onSave(name, p, m, password); dismiss()
                        }
                    }
                    .disabled(p12URL == nil || mobURL == nil || name.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(accent)
    }
    
    private func importRow(label: String, picked: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                Spacer()
                Image(systemName: picked ? "checkmark.circle.fill" : "chevron.right")
            }
        }
        .buttonStyle(GlassCapsuleButtonStyle(minWidth: nil, height: 40))
    }
}
