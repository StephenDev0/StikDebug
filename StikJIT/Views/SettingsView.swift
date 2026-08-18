//  SettingsView.swift
//  StikJIT
//
//  Created by Stephen on 3/27/25.

import SwiftUI
import UIKit

private enum SettingsLinks {
    static let githubStars = URL(string: "https://github.com/StephenDev0/StikDebug/stargazers")!
    static let pairingFileGuide = URL(string: "https://github.com/StephenDev0/StikDebug-Guide/blob/main/pairing_file.md")!
    static let discord = URL(string: "https://discord.gg/qahjXNTDwS")!
}

struct SettingsView: View {
    @AppStorage(UserDefaults.Keys.txmOverride) private var overrideTXMDetection = false
    @AppStorage("keepAliveAudio") private var keepAliveAudio = true
    @AppStorage("keepAliveLocation") private var keepAliveLocation = true
    @AppStorage("customTargetIP") private var customTargetIP = ""
    @Environment(LanguageManager.self) private var langManager
    @StateObject private var vpnManager = StikDebugVPNManager.shared

    @State private var isShowingPairingFilePicker = false
    @State private var isImportingFile = false
    @State private var pairingImportMessage: (text: String, isError: Bool)?
    @State private var showDDIConfirmation = false
    @State private var isRedownloadingDDI = false
    @State private var ddiDownloadProgress: Double = 0.0
    @State private var ddiStatusMessage: String = ""
    @State private var ddiResultMessage: (text: String, isError: Bool)?
    @State private var vpnErrorMessage: String?

    private var appVersion: String {
        let marketingVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return marketingVersion
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image("StikDebug")
                                .resizable().aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            Text("StikDebug").font(.title2.weight(.semibold))
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }

                Section {
                    Link(destination: SettingsLinks.githubStars) {
                        Label("Star on GitHub".localized, systemImage: "star")
                    }
                }

                Section("Language".localized) {
                    Picker("Language".localized, selection: Binding(
                        get: { langManager.language },
                        set: { langManager.language = $0 }
                    )) {
                        Text("简体中文").tag("zh-Hans")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Pairing File".localized) {
                    Button {
                        isShowingPairingFilePicker = true
                    } label: {
                        Label("Import Pairing File".localized, systemImage: "doc.badge.plus")
                    }
                    .disabled(isImportingFile)

                    if isImportingFile {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Importing pairing file…".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let pairingImportMessage {
                        Label(
                            pairingImportMessage.text,
                            systemImage: pairingImportMessage.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(pairingImportMessage.isError ? .red : .green)
                    }
                }

                Section("Embedded VPN".localized) {
                    HStack {
                        Label(vpnStatusTitle.localized, systemImage: vpnStatusIcon)
                        Spacer()
                        Circle()
                            .fill(vpnStatusColor)
                            .frame(width: 9, height: 9)
                    }

                    if vpnManager.currentStatus == .connected || vpnManager.currentStatus == .connecting {
                        Button {
                            vpnManager.stop()
                            vpnErrorMessage = nil
                        } label: {
                            Label("Stop VPN".localized, systemImage: "stop.circle")
                        }
                    } else {
                        Button {
                            startEmbeddedVPN()
                        } label: {
                            Label("Start VPN".localized, systemImage: "play.circle")
                        }
                        .disabled(vpnManager.currentStatus == .connecting)
                    }

                    if let vpnErrorMessage {
                        Text(vpnErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Toggle(isOn: $keepAliveAudio) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Silent Audio".localized)
                            Text("Plays inaudible audio so iOS keeps the app running.".localized)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: keepAliveAudio) { _, enabled in
                        if enabled { BackgroundAudioManager.shared.start() }
                        else { BackgroundAudioManager.shared.stop() }
                    }

                    Toggle(isOn: $keepAliveLocation) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Background Location".localized)
                            Text("Uses low-accuracy location to stay alive when an activity needs it.".localized)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: keepAliveLocation) { _, enabled in
                        if !enabled { BackgroundLocationManager.shared.stop() }
                    }

                } header: {
                    Text("Background Keep-Alive".localized)
                }

                Section("Behavior".localized) {
                    Toggle(isOn: $overrideTXMDetection) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Always Run Scripts".localized)
                            Text("Treats device as TXM-capable to bypass hardware checks.".localized)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Advanced".localized) {
                    HStack {
                        Text("Target Device IP".localized)
                        Spacer()
                        TextField("10.7.0.1", text: $customTargetIP)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                            .submitLabel(.done)
                    }
                    Button { openAppFolder() } label: {
                        Label("App Folder".localized, systemImage: "folder")
                    }.foregroundStyle(.primary)
                    Button { showDDIConfirmation = true } label: {
                        Label("Redownload DDI".localized, systemImage: "arrow.down.circle")
                    }.foregroundStyle(.primary).disabled(isRedownloadingDDI)
                    if isRedownloadingDDI {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: ddiDownloadProgress, total: 1.0)
                            Text(ddiStatusMessage).font(.caption).foregroundStyle(.secondary)
                        }
                    } else if let result = ddiResultMessage {
                        Text(result.text).font(.caption).foregroundStyle(result.isError ? .red : .green)
                    }
                }

                Section("Help".localized) {
                    Link(destination: SettingsLinks.pairingFileGuide) {
                        Label("Pairing File Guide".localized, systemImage: "questionmark.circle")
                    }
                    Link(destination: SettingsLinks.discord) {
                        Label("Discord Support".localized, systemImage: "bubble.left.and.bubble.right")
                    }
                }

                Section {
                    Text(versionFooter)
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings".localized)
        }
        .fileImporter(
            isPresented: $isShowingPairingFilePicker,
            allowedContentTypes: PairingFileStore.supportedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }

                let fileManager = FileManager.default
                isImportingFile = true
                pairingImportMessage = nil

                do {
                    try PairingFileStore.importFromPicker(url, fileManager: fileManager)
                    isImportingFile = false
                    pairingImportMessage = ("Imported successfully".localized, false)
                    startTunnelInBackground()
                    schedulePairingStatusDismiss()
                } catch {
                    isImportingFile = false
                    pairingImportMessage = (String(format: "Import failed: %@".localized, error.localizedDescription), true)
                    schedulePairingStatusDismiss()
                }
            case .failure(let error):
                isImportingFile = false
                pairingImportMessage = (String(format: "Import failed: %@".localized, error.localizedDescription), true)
                schedulePairingStatusDismiss()
            }
        }
        .confirmationDialog("Redownload DDI Files?".localized, isPresented: $showDDIConfirmation, titleVisibility: .visible) {
            Button("Redownload".localized, role: .destructive) {
                redownloadDDIPressed()
            }
            Button("Cancel".localized, role: .cancel) { }
        } message: {
            Text("Existing DDI files will be removed before downloading fresh copies.".localized)
        }
    }

    private var versionFooter: String {
        let processInfo = ProcessInfo.processInfo
        let txmLabel: String
        if processInfo.isTXMOverridden {
            txmLabel = "TXM (Override)"
        } else {
            txmLabel = processInfo.hasTXM ? "TXM" : "Non TXM"
        }
        return "Version \(appVersion) • iOS \(UIDevice.current.systemVersion) • \(txmLabel)"
    }

    private var vpnStatusTitle: String {
        switch vpnManager.currentStatus {
        case .connected:
            return "VPN connected"
        case .connecting:
            return "VPN connecting"
        case .disconnecting:
            return "VPN connecting"
        case .failed:
            return "VPN failed"
        case .disconnected:
            return "VPN disconnected"
        }
    }

    private var vpnStatusIcon: String {
        switch vpnManager.currentStatus {
        case .connected:
            return "checkmark.shield.fill"
        case .connecting, .disconnecting:
            return "arrow.triangle.2.circlepath"
        case .failed:
            return "exclamationmark.shield.fill"
        case .disconnected:
            return "shield.slash"
        }
    }

    private var vpnStatusColor: Color {
        switch vpnManager.currentStatus {
        case .connected:
            return .green
        case .connecting, .disconnecting:
            return .orange
        case .failed:
            return .red
        case .disconnected:
            return .secondary
        }
    }

    private func startEmbeddedVPN() {
        vpnErrorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try vpnManager.start()
            } catch {
                DispatchQueue.main.async {
                    vpnErrorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Business Logic

    private func openAppFolder() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let path = documentsURL.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://")
        if let url = URL(string: path) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    private func redownloadDDIPressed() {
        guard !isRedownloadingDDI else { return }
        Task {
            await MainActor.run {
                isRedownloadingDDI = true
                ddiDownloadProgress = 0
                ddiStatusMessage = "Preparing download…".localized
                ddiResultMessage = nil
            }
            do {
                try await redownloadDDI { progress, status in
                    Task { @MainActor in
                        self.ddiDownloadProgress = progress
                        self.ddiStatusMessage = status
                    }
                }
                await MainActor.run {
                    isRedownloadingDDI = false
                    ddiResultMessage = ("DDI files refreshed successfully.".localized, false)
                }
            } catch {
                await MainActor.run {
                    isRedownloadingDDI = false
                    ddiResultMessage = (String(format: "Failed to redownload DDI files: %@".localized, error.localizedDescription), true)
                }
            }
        }
        scheduleDDIStatusDismiss()
    }

    private func schedulePairingStatusDismiss() {
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                if !isImportingFile {
                    pairingImportMessage = nil
                }
            }
        }
    }

    private func scheduleDDIStatusDismiss() {
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                if !isRedownloadingDDI {
                    ddiResultMessage = nil
                }
            }
        }
    }
}
