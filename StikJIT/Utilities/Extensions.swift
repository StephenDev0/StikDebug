//
//  Extensions.swift
//  StikDebug
//
//  Created by s s on 2025/7/9.
//
import Foundation
import UniformTypeIdentifiers
import UIKit

enum PairingFileStore {
    static let fileName = "rp_pairing_file.plist"
    private static let legacyFileName = "pairingFile.plist"
    static let supportedContentTypes: [UTType] = [
        UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!,
        UTType(filenameExtension: "mobiledevicepair", conformingTo: .data)!,
        .propertyList
    ]

    static var url: URL {
        URL.documentsDirectory.appendingPathComponent(fileName)
    }

    private static var legacyURL: URL {
        URL.documentsDirectory.appendingPathComponent(legacyFileName)
    }

    @discardableResult
    static func prepareURL(fileManager: FileManager = .default) -> URL {
        let destination = url
        guard !fileManager.fileExists(atPath: destination.path),
              fileManager.fileExists(atPath: legacyURL.path) else {
            return destination
        }

        do {
            try fileManager.moveItem(at: legacyURL, to: destination)
        } catch {
            if let data = try? Data(contentsOf: legacyURL) {
                try? data.write(to: destination, options: .atomic)
                try? fileManager.removeItem(at: legacyURL)
            }
        }

        return destination
    }

    static func replace(with sourceURL: URL, fileManager: FileManager = .default) throws {
        let destination = prepareURL(fileManager: fileManager)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        if fileManager.fileExists(atPath: legacyURL.path) {
            try? fileManager.removeItem(at: legacyURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }

    static func importFromPicker(_ sourceURL: URL, fileManager: FileManager = .default) throws {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        try replace(with: sourceURL, fileManager: fileManager)
    }

    static func remove(fileManager: FileManager = .default) throws {
        let destination = prepareURL(fileManager: fileManager)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        if fileManager.fileExists(atPath: legacyURL.path) {
            try? fileManager.removeItem(at: legacyURL)
        }
    }
}

struct ScriptResource {
    let resourceName: String
    let fileName: String
}

enum ScriptStore {
    static let directoryName = "scripts"
    static let assignmentKey = UserDefaults.Keys.bundleScriptMap
    static let favoriteAppNamesSuiteName = "group.com.stik.sj"
    static let favoriteAppNamesKey = "favoriteAppNames"
    static let defaultScriptName = UserDefaults.Keys.defaultScriptNameValue
    static let bundledResources: [ScriptResource] = [
        ScriptResource(resourceName: "attachDetach", fileName: "attachDetach.js"),
        ScriptResource(resourceName: "maciOS", fileName: "maciOS.js"),
        ScriptResource(resourceName: "universal", fileName: "universal.js"),
        ScriptResource(resourceName: "Geode", fileName: "Geode.js"),
        ScriptResource(resourceName: "manic", fileName: "manic.js"),
        ScriptResource(resourceName: "UTM-Dolphin", fileName: "UTM-Dolphin.js")
    ]

    static var directoryURL: URL {
        URL.documentsDirectory.appendingPathComponent(directoryName)
    }

    @discardableResult
    static func prepareDirectory(fileManager: FileManager = .default) throws -> URL {
        let directory = directoryURL
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory)
        if exists && !isDirectory.boolValue {
            try fileManager.removeItem(at: directory)
        }
        if !exists || !isDirectory.boolValue {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try ensureBundledScripts(in: directory, fileManager: fileManager)
        return directory
    }

    static func scriptURL(named scriptName: String, fileManager: FileManager = .default) throws -> URL {
        let directory = try prepareDirectory(fileManager: fileManager)
        return directory.appendingPathComponent(scriptName)
    }

    static func assignedScriptName(for bundleID: String, defaults: UserDefaults = .standard) -> String? {
        assignedScriptMap(defaults: defaults)[bundleID]
    }

    static func updateAssignedScriptName(_ scriptName: String?, for bundleID: String, defaults: UserDefaults = .standard) {
        var mapping = assignedScriptMap(defaults: defaults)
        if let scriptName {
            mapping[bundleID] = scriptName
        } else {
            mapping.removeValue(forKey: bundleID)
        }
        defaults.set(mapping, forKey: assignmentKey)
    }

    static func preferredScript(for bundleID: String, fileManager: FileManager = .default) -> (data: Data, name: String)? {
        assignedScript(for: bundleID, fileManager: fileManager) ?? autoScript(for: bundleID, fileManager: fileManager)
    }

    static func favoriteAppName(for bundleID: String, defaults: UserDefaults? = UserDefaults(suiteName: favoriteAppNamesSuiteName)) -> String? {
        let names = defaults?.dictionary(forKey: favoriteAppNamesKey) as? [String: String]
        return names?[bundleID]
    }

    static func autoScriptResource(for appName: String) -> ScriptResource? {
        switch appName {
        case "maciOS":
            return ScriptResource(resourceName: "maciOS", fileName: "maciOS.js")
        case "Amethyst", "MeloNX", "XeniOS", "MeloCafe":
            return ScriptResource(resourceName: "universal", fileName: "universal.js")
        case "Geode":
            return ScriptResource(resourceName: "Geode", fileName: "Geode.js")
        case "Manic EMU":
            return ScriptResource(resourceName: "manic", fileName: "manic.js")
        case "UTM", "DolphiniOS", "Flycast":
            return ScriptResource(resourceName: "UTM-Dolphin", fileName: "UTM-Dolphin.js")
        default:
            return nil
        }
    }

    private static func ensureBundledScripts(in directory: URL, fileManager: FileManager) throws {
        for resource in bundledResources {
            guard let bundleURL = Bundle.main.url(forResource: resource.resourceName, withExtension: "js") else {
                continue
            }
            let destination = directory.appendingPathComponent(resource.fileName)
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.copyItem(at: bundleURL, to: destination)
            }
        }
    }

    private static func assignedScript(for bundleID: String, fileManager: FileManager) -> (data: Data, name: String)? {
        guard let scriptName = assignedScriptName(for: bundleID) else {
            return nil
        }
        guard let scriptURL = try? scriptURL(named: scriptName, fileManager: fileManager),
              let data = try? Data(contentsOf: scriptURL) else {
            return nil
        }
        return (data, scriptName)
    }

    private static func autoScript(for bundleID: String, fileManager: FileManager) -> (data: Data, name: String)? {
        guard ProcessInfo.processInfo.hasTXM else {
            return nil
        }
        guard #available(iOS 26, *) else {
            return nil
        }

        let appName = (try? JITEnableContext.shared.getAppList()[bundleID]) ?? favoriteAppName(for: bundleID)
        guard let appName,
              let resource = autoScriptResource(for: appName) else {
            return nil
        }

        if let scriptURL = try? scriptURL(named: resource.fileName, fileManager: fileManager),
           let data = try? Data(contentsOf: scriptURL) {
            return (data, resource.fileName)
        }

        guard let bundleURL = Bundle.main.url(forResource: resource.resourceName, withExtension: "js"),
              let data = try? Data(contentsOf: bundleURL) else {
            return nil
        }
        return (data, resource.fileName)
    }

    private static func assignedScriptMap(defaults: UserDefaults) -> [String: String] {
        defaults.dictionary(forKey: assignmentKey) as? [String: String] ?? [:]
    }
}

extension FileManager {
    func filePath(atPath path: String, withLength length: Int) -> String? {
        guard let file = try? contentsOfDirectory(atPath: path).first(where: { $0.count == length }) else { return nil }
        return "\(path)/\(file)"
    }
}

extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

extension Notification.Name {
    static let pairingFileImported = Notification.Name("PairingFileImported")
    static let intentJSScriptReady = Notification.Name("intentJSScriptReady")
}

extension UserDefaults {
    enum Keys {
        /// Forces the app to treat the current device as TXM-capable so scripts always run.
        static let txmOverride = "overrideTXMForScripts"
        static let bundleScriptMap = "BundleScriptMap"
        static let defaultScriptName = "DefaultScriptName"
        static let defaultScriptNameValue = "attachDetach.js"
    }
}
