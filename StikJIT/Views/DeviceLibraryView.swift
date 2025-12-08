//
//  DeviceLibraryView.swift
//  StikJIT
//
//  Created by Stephen.
//

import SwiftUI
import UniformTypeIdentifiers

private struct DeviceAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let isError: Bool
}

private enum DeviceEditorMode: Identifiable {
    case add
    case edit(DeviceProfileEntry)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let device): return device.id.uuidString
        }
    }
}

struct DeviceLibraryView: View {
    @StateObject private var store = DeviceLibraryStore.shared
    @State private var editorMode: DeviceEditorMode?
    @State private var alert: DeviceAlert?
    @State private var isActivatingDevice = false
    
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.themeExpansionManager) private var themeExpansion
    
    private var backgroundStyle: BackgroundStyle { themeExpansion?.backgroundStyle(for: appThemeRaw) ?? AppTheme.system.backgroundStyle }
    private var preferredScheme: ColorScheme? { themeExpansion?.preferredColorScheme(for: appThemeRaw) }
    private var accentColor: Color { themeExpansion?.resolvedAccentColor(from: customAccentColorHex) ?? .blue }
    
    private var savedDevices: [DeviceProfileEntry] {
        store.devices.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    private var displayedDevices: [DeviceProfileEntry] {
        [store.defaultLocalDevice] + savedDevices
    }
    
    private var activeSubtitle: String {
        store.activeDevice != nil
            ? "Currently using an external device."
            : "No external device selected."
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground(style: backgroundStyle)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        fullWidthCard {
                            VStack(alignment: .leading, spacing: 16) {
                                headerRow
                                activeSummaryCard
                                
                                ForEach(displayedDevices) { device in
                                    let isDefault = store.isDefaultDevice(device)
                                    DeviceRow(device: device,
                                              isActive: isDefault ? !store.isUsingExternalDevice : store.activeDeviceID == device.id,
                                              isDefault: isDefault,
                                              accentColor: accentColor,
                                              onActivate: { activate(device: device) },
                                              onEdit: isDefault ? nil : { editorMode = .edit(device) },
                                              onDelete: isDefault ? nil : { delete(device: device) })
                                    if device.id != displayedDevices.last?.id {
                                        Divider()
                                    }
                                }
                                
                                footerText
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorMode = .add
                    } label: {
                        Label("Add Device", systemImage: "plus")
                    }
                }
            }
        }
        .tint(accentColor)
        .preferredColorScheme(preferredScheme)
        .disabled(isActivatingDevice)
        .sheet(item: $editorMode) { mode in
            DeviceEditorSheet(mode: mode) { input in
                try handleSave(mode: mode, input: input)
                if case .edit(let originalDevice) = mode,
                   store.activeDeviceID == originalDevice.id,
                   input.pairingData != nil {
                    if let refreshedDevice = store.devices.first(where: { $0.id == originalDevice.id }) {
                        do {
                            try store.activate(device: refreshedDevice)
                            startHeartbeatInBackground(requireVPNConnection: false)
                            alert = DeviceAlert(title: "Pairing Updated",
                                                message: "\(refreshedDevice.name)'s pairing file was refreshed.",
                                                isError: false)
                        } catch {
                            alert = DeviceAlert(title: "Activation Failed",
                                                message: error.localizedDescription,
                                                isError: true)
                        }
                    }
                }
            }
        }
        .alert(item: $alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func handleSave(mode: DeviceEditorMode, input: DeviceEditorInput) throws {
        switch mode {
        case .add:
            try store.addDevice(name: input.name,
                                ipAddress: input.ipAddress,
                                pairingData: input.pairingData,
                                originalFilename: input.pairingFilename,
                                isTXM: input.isTXM)
            alert = DeviceAlert(title: "Device Saved", message: "\(input.name) was added to your library.", isError: false)
        case .edit(let device):
            try store.update(device: device,
                             name: input.name,
                             ipAddress: input.ipAddress,
                             pairingData: input.pairingData,
                             originalFilename: input.pairingFilename ?? device.pairingFilename,
                             isTXM: input.isTXM)
            alert = DeviceAlert(title: "Device Updated", message: "\(input.name) has been updated.", isError: false)
        }
    }
    
    private func activate(device: DeviceProfileEntry) {
        guard !isActivatingDevice else { return }
        isActivatingDevice = true
        defer { isActivatingDevice = false }
        let activatingDefault = store.isDefaultDevice(device)
        do {
            try store.activate(device: device)
            startHeartbeatInBackground(requireVPNConnection: false)
            let title = activatingDefault ? "Loopback Active" : "Device Activated"
            let message = activatingDefault
                ? "Switched back to debugging this device over the loopback VPN."
                : "\(device.name) is now active. The heartbeat will refresh automatically."
            alert = DeviceAlert(title: title, message: message, isError: false)
        } catch {
            alert = DeviceAlert(title: "Activation Failed",
                                message: error.localizedDescription,
                                isError: true)
        }
    }
    
    private func delete(device: DeviceProfileEntry) {
        do {
            try store.remove(device: device)
        } catch {
            alert = DeviceAlert(title: "Delete Failed", message: error.localizedDescription, isError: true)
        }
    }

    @ViewBuilder
    private func fullWidthCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        appGlassCard {
            content()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {

                    Text("Device Library")
                        .font(.system(.title, design: .rounded).weight(.bold))
                }
                Spacer()
            }
            
            Text("Manage saved targets and switch between local or remote hardware.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var activeSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(activeSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: store.isUsingExternalDevice ? "antenna.radiowaves.left.and.right" : "iphone")
                    .foregroundColor(accentColor)
            }
            
            if let active = store.activeDevice {
                let relative = relativeDateFormatter.localizedString(for: active.lastUpdated, relativeTo: Date())
                VStack(alignment: .leading, spacing: 4) {
                    Text(active.name)
                        .font(.headline)
                    Text("IP: \(active.ipAddress)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Synced \(relative).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Button {
                    activate(device: store.defaultLocalDevice)
                } label: {
                    Label("Switch to This Device", systemImage: "arrow.uturn.backward")
                        .font(.footnote.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
            } else {
                Text("Using the on-device pairing file. Saved devices appear below for quick switching.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    private var footerText: some View {
        Text("Saved devices keep their own pairing files so you can connect without copying them manually.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }
}

private struct DeviceRow: View {
    let device: DeviceProfileEntry
    let isActive: Bool
    let isDefault: Bool
    let accentColor: Color
    let onActivate: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.name)
                            .font(.headline)
                        if isActive {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(accentColor.opacity(0.15), in: Capsule())
                                .foregroundColor(accentColor)
                        }
                    }
                    if isDefault {
                        Text("Loopback IP: \(device.ipAddress)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Uses the pairing file already stored on this device.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        Text("IP: \(device.ipAddress)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Pairing: \(device.pairingFilename)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        if device.isTXM {
                            Label("TXM Capable", systemImage: "shield.checkerboard")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15), in: Capsule())
                                .foregroundColor(.green)
                        } else {
                            Label("Non-TXM", systemImage: "xmark.shield")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                if onEdit != nil || onDelete != nil {
                    Menu {
                        Button("Use Device", action: onActivate)
                        if let onEdit {
                            Button("Edit Details", action: onEdit)
                        }
                        if let onDelete {
                            Button(role: .destructive, action: onDelete) {
                                Text("Delete Device")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button(action: onActivate) {
                let title = isActive ? "Active" : (isDefault ? "Use Loopback" : "Use This Device")
                HStack {
                    Image(systemName: isDefault ? "iphone" : "bolt.fill")
                    Text(title).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isActive ? Color.gray.opacity(0.2) : accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundColor(isActive ? .secondary : accentColor)
            }
            .disabled(isActive)
        }
    }
}

// MARK: - Editor Sheet

private struct DeviceEditorInput {
    var name: String
    var ipAddress: String
    var pairingData: Data?
    var pairingFilename: String?
    var isTXM: Bool
}

private struct DeviceEditorSheet: View {
    let mode: DeviceEditorMode
    let onSave: (DeviceEditorInput) throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.themeExpansionManager) private var themeExpansion
    
    @State private var name: String
    @State private var ipAddress: String
    @State private var pairingData: Data?
    @State private var selectedFilename: String?
    @State private var errorMessage: String?
    @State private var showImporter = false
    @State private var isTXMDevice: Bool
    
    private var accentColor: Color { themeExpansion?.resolvedAccentColor(from: customAccentColorHex) ?? .blue }
    private var requiresPairing: Bool {
        if case .add = mode { return true }
        return false
    }
    private var existingFilename: String? {
        if case .edit(let device) = mode {
            return device.pairingFilename
        }
        return nil
    }
    private var title: String {
        switch mode {
        case .add: return "New Device"
        case .edit: return "Edit Device"
        }
    }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ipAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!requiresPairing || pairingData != nil)
    }
    
    init(mode: DeviceEditorMode, onSave: @escaping (DeviceEditorInput) throws -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _ipAddress = State(initialValue: "10.7.0.1")
            _isTXMDevice = State(initialValue: false)
        case .edit(let device):
            _name = State(initialValue: device.name)
            _ipAddress = State(initialValue: device.ipAddress)
            _isTXMDevice = State(initialValue: device.isTXM)
        }
        _selectedFilename = State(initialValue: nil)
        _pairingData = State(initialValue: nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Display Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Device IP", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                    Toggle(isOn: $isTXMDevice) {
                        Text("TXM Capable")
                    }
                    .tint(accentColor)
                    Text("Enable if this device includes the Trusted Execution Monitor (TXM).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Pairing File")) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Select Pairing File", systemImage: "doc.badge")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    
                    if let filename = selectedFilename {
                        Text("Selected: \(filename)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else if let existing = existingFilename {
                        Text("Current: \(existing)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No file selected")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [
                    UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!,
                    .propertyList
                ],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessing { url.stopAccessingSecurityScopedResource() }
                    }
                    do {
                        pairingData = try Data(contentsOf: url)
                        selectedFilename = url.lastPathComponent
                        errorMessage = nil
                    } catch {
                        errorMessage = "Failed to read file: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
        .tint(accentColor)
    }
    
    private func save() {
        guard canSave else { return }
        do {
            try onSave(DeviceEditorInput(
                name: name,
                ipAddress: ipAddress,
                pairingData: pairingData,
                pairingFilename: selectedFilename ?? existingFilename,
                isTXM: isTXMDevice
            ))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
