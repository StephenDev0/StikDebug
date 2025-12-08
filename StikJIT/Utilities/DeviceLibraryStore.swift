//
//  DeviceLibraryStore.swift
//  StikJIT
//
//  Created by Stephen.
//

import Foundation

struct DeviceProfileEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var ipAddress: String
    var pairingRelativePath: String
    var pairingFilename: String
    var dateAdded: Date
    var lastUpdated: Date
    var isTXM: Bool

    init(id: UUID,
         name: String,
         ipAddress: String,
         pairingRelativePath: String,
         pairingFilename: String,
         dateAdded: Date,
         lastUpdated: Date,
         isTXM: Bool = false) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.pairingRelativePath = pairingRelativePath
        self.pairingFilename = pairingFilename
        self.dateAdded = dateAdded
        self.lastUpdated = lastUpdated
        self.isTXM = isTXM
    }

    enum CodingKeys: String, CodingKey {
        case id, name, ipAddress, pairingRelativePath, pairingFilename, dateAdded, lastUpdated, isTXM
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        ipAddress = try container.decode(String.self, forKey: .ipAddress)
        pairingRelativePath = try container.decode(String.self, forKey: .pairingRelativePath)
        pairingFilename = try container.decode(String.self, forKey: .pairingFilename)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        isTXM = try container.decodeIfPresent(Bool.self, forKey: .isTXM) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(ipAddress, forKey: .ipAddress)
        try container.encode(pairingRelativePath, forKey: .pairingRelativePath)
        try container.encode(pairingFilename, forKey: .pairingFilename)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(isTXM, forKey: .isTXM)
    }
}

enum DeviceLibraryError: LocalizedError {
    case missingPairingData
    case deviceNotFound
    case pairingFileUnavailable
    case fileOperationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingPairingData:
            return "Select a pairing file before saving."
        case .deviceNotFound:
            return "The selected device could not be found."
        case .pairingFileUnavailable:
            return "The pairing file for this device is missing. Re-import it and try again."
        case .fileOperationFailed(let reason):
            return reason
        }
    }
}

final class DeviceLibraryStore: ObservableObject {
    static let shared = DeviceLibraryStore()
    
    @Published private(set) var devices: [DeviceProfileEntry] = []
    @Published private(set) var activeDeviceID: UUID?
    
    var activeDevice: DeviceProfileEntry? {
        guard let activeDeviceID else { return nil }
        return devices.first(where: { $0.id == activeDeviceID })
    }
    
    var isUsingExternalDevice: Bool {
        activeDeviceID != nil
    }
    
    var defaultLocalDevice: DeviceProfileEntry {
        DeviceProfileEntry(
            id: localLoopbackID,
            name: "This Device",
            ipAddress: "10.7.0.2",
            pairingRelativePath: "",
            pairingFilename: "pairingFile.plist",
            dateAdded: Date.distantPast,
            lastUpdated: Date.distantPast
        )
    }
    
    private let fileManager = FileManager.default
    private let storageURL: URL
    private let pairingsDirectory: URL
    private let baseDirectory: URL
    private let activeDeviceKey = "DeviceLibraryActiveDeviceID"
    private let localLoopbackID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    
    private init() {
        baseDirectory = URL.documentsDirectory.appendingPathComponent("DeviceLibrary", isDirectory: true)
        pairingsDirectory = baseDirectory.appendingPathComponent("Pairings", isDirectory: true)
        storageURL = baseDirectory.appendingPathComponent("devices.json")
        createDirectoriesIfNeeded()
        loadFromDisk()
        if let rawValue = UserDefaults.standard.string(forKey: activeDeviceKey),
           let uuid = UUID(uuidString: rawValue),
           devices.contains(where: { $0.id == uuid }) {
            activeDeviceID = uuid
        } else {
            UserDefaults.standard.removeObject(forKey: activeDeviceKey)
            UserDefaults.standard.set(false, forKey: UserDefaults.Keys.usingExternalDevice)
            activeDeviceID = nil
        }
        updateExternalDeviceFlag()
    }
    
    // MARK: - Public API
    
    func refresh() {
        loadFromDisk()
    }
    
    func addDevice(name: String,
                   ipAddress: String,
                   pairingData: Data?,
                   originalFilename: String?,
                   isTXM: Bool) throws {
        guard let pairingData else {
            throw DeviceLibraryError.missingPairingData
        }
        
        let id = UUID()
        let now = Date()
        let relativePath = try persistPairingData(pairingData, for: id)
        let entry = DeviceProfileEntry(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            ipAddress: ipAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            pairingRelativePath: relativePath,
            pairingFilename: originalFilename ?? "pairingFile.plist",
            dateAdded: now,
            lastUpdated: now,
            isTXM: isTXM
        )
        devices.append(entry)
        persistDevices()
    }
    
    func update(device: DeviceProfileEntry,
                name: String,
                ipAddress: String,
                pairingData: Data?,
                originalFilename: String?,
                isTXM: Bool) throws {
        guard !isDefaultDevice(device) else { return }
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else {
            throw DeviceLibraryError.deviceNotFound
        }
        
        devices[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        devices[index].ipAddress = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        devices[index].lastUpdated = Date()
        devices[index].isTXM = isTXM
        if activeDeviceID == device.id {
            UserDefaults.standard.set(devices[index].ipAddress, forKey: "TunnelDeviceIP")
        }
        
        if let pairingData {
            let relativePath = try persistPairingData(pairingData, for: device.id)
            devices[index].pairingRelativePath = relativePath
            if let originalFilename {
                devices[index].pairingFilename = originalFilename
            }
        }
        
        persistDevices()
    }
    
    func remove(device: DeviceProfileEntry) throws {
        guard !isDefaultDevice(device) else { return }
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else {
            throw DeviceLibraryError.deviceNotFound
        }
        
        let relativePath = devices[index].pairingRelativePath
        let storedURL = pairingsDirectory.appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: storedURL.path) {
            try? fileManager.removeItem(at: storedURL)
        }
        
        devices.remove(at: index)
        if activeDeviceID == device.id {
            clearActiveDevice()
        }
        persistDevices()
    }
    
    func activate(device: DeviceProfileEntry) throws {
        if isDefaultDevice(device) {
            clearActiveDevice()
            return
        }
        let storedURL = pairingsDirectory.appendingPathComponent(device.pairingRelativePath)
        guard fileManager.fileExists(atPath: storedURL.path) else {
            throw DeviceLibraryError.pairingFileUnavailable
        }
        let destinationURL = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: storedURL, to: destinationURL)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
        
        UserDefaults.standard.set(device.ipAddress, forKey: "TunnelDeviceIP")
        activeDeviceID = device.id
        UserDefaults.standard.set(device.id.uuidString, forKey: activeDeviceKey)
        UserDefaults.standard.set(true, forKey: UserDefaults.Keys.usingExternalDevice)
        persistDevices()
        updateExternalDeviceFlag()
    }
    
    func clearActiveDevice() {
        activeDeviceID = nil
        UserDefaults.standard.removeObject(forKey: activeDeviceKey)
        UserDefaults.standard.set(false, forKey: UserDefaults.Keys.usingExternalDevice)
        UserDefaults.standard.removeObject(forKey: "TunnelDeviceIP")
        updateExternalDeviceFlag()
    }
    
    // MARK: - Persistence
    
    private func createDirectoriesIfNeeded() {
        do {
            if !fileManager.fileExists(atPath: baseDirectory.path) {
                try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            }
            if !fileManager.fileExists(atPath: pairingsDirectory.path) {
                try fileManager.createDirectory(at: pairingsDirectory, withIntermediateDirectories: true)
            }
        } catch {
            print("Failed to create DeviceLibrary directories: \(error)")
        }
    }
    
    private func persistPairingData(_ data: Data, for id: UUID) throws -> String {
        createDirectoriesIfNeeded()
        let filename = "\(id.uuidString).mobiledevicepairing"
        let destination = pairingsDirectory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        do {
            try data.write(to: destination, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch {
            throw DeviceLibraryError.fileOperationFailed("Unable to store pairing file. \(error.localizedDescription)")
        }
        return filename
    }
    
    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            devices = []
            return
        }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([DeviceProfileEntry].self, from: data)
            devices = decoded
        } catch {
            print("Failed to load device library: \(error)")
            devices = []
        }
        if let activeDeviceID, !devices.contains(where: { $0.id == activeDeviceID }) {
            clearActiveDevice()
        }
        updateExternalDeviceFlag()
    }
    
    private func persistDevices() {
        do {
            createDirectoriesIfNeeded()
            let data = try JSONEncoder().encode(devices)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save device library: \(error)")
        }
    }
    
    private func updateExternalDeviceFlag() {
        UserDefaults.standard.set(isUsingExternalDevice, forKey: UserDefaults.Keys.usingExternalDevice)
    }
    
    func isDefaultDevice(_ device: DeviceProfileEntry) -> Bool {
        device.id == localLoopbackID
    }
}
