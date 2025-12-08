//
//  ContentView.swift
//  StikJIT
//
//  Created by Stephen on 3/26/25.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit
import WidgetKit
import Combine
import Network

struct JITEnableConfiguration {
    var bundleID: String? = nil
    var pid : Int? = nil
    var scriptData: Data? = nil
    var scriptName : String? = nil
}

struct HomeView: View {
    
    @AppStorage("username") private var username = "User"
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accentColor) private var environmentAccentColor
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @AppStorage("bundleID") private var bundleID: String = ""
    @AppStorage("recentApps") private var recentApps: [String] = []
    @AppStorage("favoriteApps") private var favoriteApps: [String] = []
    @State private var isProcessing = false
    @State private var isShowingInstalledApps = false
    @State private var isShowingPairingFilePicker = false
    @State private var pairingFileExists: Bool = false
    @State private var pairingFilePresentOnDisk: Bool = false
    @State private var isValidatingPairingFile = false
    @State private var lastValidatedPairingSignature: PairingFileSignature? = nil
    @State private var showPairingFileMessage = false
    @State private var pairingFileIsValid = false
    @State private var isImportingFile = false
    @State private var importProgress: Float = 0.0
    
    @State private var showPIDSheet = false
    @AppStorage("recentPIDs") private var recentPIDs: [Int] = []
    @State private var justCopied = false
    
    @State private var viewDidAppeared = false
    @State private var pendingJITEnableConfiguration : JITEnableConfiguration? = nil
    @AppStorage("enableAdvancedOptions") private var enableAdvancedOptions = false
    
    @State var scriptViewShow = false
    @AppStorage("DefaultScriptName") var selectedScript = "attachDetach.js"
    @State var jsModel: RunJSViewModel?
    
    @StateObject private var tunnel = TunnelManager.shared
    @ObservedObject private var mounting = MountingProgress.shared
    @ObservedObject private var deviceStore = DeviceLibraryStore.shared
    @State private var heartbeatOK = false
    @State private var cachedAppNames: [String: String] = [:]
    @AppStorage("pinnedSystemApps") private var pinnedSystemApps: [String] = []
    @AppStorage("pinnedSystemAppNames") private var pinnedSystemAppNames: [String: String] = [:]
    @State private var launchingSystemApps: Set<String> = []
    @State private var systemLaunchMessage: String? = nil
    @State private var connectionCheckState: ConnectionCheckState = .idle
    @State private var connectionInfoMessage: String? = nil
    @State private var hasAutoStartedConnectionCheck = false
    @State private var connectionTimeoutTask: DispatchWorkItem? = nil
    @State private var wifiConnected = false
    @State private var wifiMonitor: NWPathMonitor? = nil
    @State private var isCellularActive = false
    @State private var cellularMonitor: NWPathMonitor? = nil
    @State private var isSchedulingInitialSetup = false
    @AppStorage("cachedAppNamesData") private var cachedAppNamesData: Data?
    @AppStorage("autoStartVPN") private var autoStartVPN = true
    
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.themeExpansionManager) private var themeExpansion
    private var backgroundStyle: BackgroundStyle { themeExpansion?.backgroundStyle(for: appThemeRaw) ?? AppTheme.system.backgroundStyle }
    private var preferredScheme: ColorScheme? { themeExpansion?.preferredColorScheme(for: appThemeRaw) }
    
    private var accentColor: Color {
        themeExpansion?.resolvedAccentColor(from: customAccentColorHex) ?? .blue
    }
    
    private var ddiMounted: Bool { mounting.coolisMounted }
    private var canConnectByApp: Bool { pairingFileExists && ddiMounted }
    private var requiresLoopbackVPN: Bool { !deviceStore.isUsingExternalDevice }
    private var pairingFileLikelyInvalid: Bool {
        (pairingFileExists || pairingFilePresentOnDisk) &&
        !isValidatingPairingFile &&
        !ddiMounted &&
        !heartbeatOK
    }
    private var sanitizedUsername: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "there" : trimmed
    }
    private var greetingTitle: String {
        "\(timeOfDayGreeting), \(sanitizedUsername)!"
    }
    private var greetingSubtitle: String {
        if canConnectByApp {
            return "You're all set. Connect whenever you're ready."
        } else if !pairingFileExists {
            return "Import your pairing file to start debugging."
        } else if !ddiMounted {
            return "Mount the DDI to finish preparing your device."
        }
        return "Complete the steps below to get ready."
    }
    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }
    private var shouldPromptForWiFi: Bool {
        pairingFileLikelyInvalid && !wifiConnected && isCellularActive
    }
    
    private let pairingFileURL = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground(style: backgroundStyle)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        welcomeCard
                        setupCard
                        connectCard
                        // if pairingFileExists {
                        //        quickConnectCard
                        //  }
                        if !pinnedLaunchItems.isEmpty {
                            launchShortcutsCard
                        }
                        tipsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }
                .scrollIndicators(.hidden)
                
                if isImportingFile {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView("Processing pairing file…")
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                }
                
                if showPairingFileMessage && pairingFileIsValid && !isImportingFile {
                    toast("✓ Pairing file successfully imported")
                }
                if justCopied {
                    toast("Copied")
                }
                if let message = systemLaunchMessage {
                    toast(message)
                }
            }
            .navigationTitle("Home")
        }
        .preferredColorScheme(preferredScheme)
        .onAppear {
            scheduleInitialSetupWork()
            startWiFiMonitoring()
            startCellularMonitoring()
            if requiresLoopbackVPN && autoStartVPN && tunnel.tunnelStatus == .disconnected {
                TunnelManager.shared.startVPN()
            }
            if !hasAutoStartedConnectionCheck {
                hasAutoStartedConnectionCheck = true
                runConnectionDiagnostics(autoStart: true)
            }
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowPairingFilePicker"),
                object: nil,
                queue: .main
            ) { _ in isShowingPairingFilePicker = true }
        }
        .onDisappear {
            connectionTimeoutTask?.cancel()
            connectionTimeoutTask = nil
            stopWiFiMonitoring()
            stopCellularMonitoring()
            hasAutoStartedConnectionCheck = false
        }
        .onReceive(timer) { _ in
            refreshBackground()
            checkPairingFileExists()
            heartbeatOK = pubHeartBeat
        }
        .onChange(of: pairingFileExists) { _, newValue in
            if newValue {
                loadAppListIfNeeded(force: cachedAppNames.isEmpty)
                runConnectionDiagnostics()
            } else {
                cachedAppNames = [:]
            }
        }
        .onChange(of: tunnel.tunnelStatus) { _, newStatus in
            guard requiresLoopbackVPN else { return }
            if newStatus == .connected {
                loadAppListIfNeeded(force: cachedAppNames.isEmpty)
                runConnectionDiagnostics()
                MountingProgress.shared.checkforMounted()
            }
        }
        .onChange(of: favoriteApps) { _, _ in
            loadAppListIfNeeded()
            syncFavoriteAppNamesWithCache()
        }
        .onChange(of: recentApps) { _, _ in
            loadAppListIfNeeded()
        }
        .fileImporter(isPresented: $isShowingPairingFilePicker, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!, .propertyList]) { result in
            switch result {
            case .success(let url):
                let fileManager = FileManager.default
                let accessing = url.startAccessingSecurityScopedResource()
                
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        let dest = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
                        if FileManager.default.fileExists(atPath: dest.path) {
                            try fileManager.removeItem(at: dest)
                        }
                        try fileManager.copyItem(at: url, to: dest)
                        
                        DispatchQueue.main.async {
                            isImportingFile = true
                            importProgress = 0
                            pairingFileExists = true
                        }
                        
                        DispatchQueue.main.async {
                            startHeartbeatInBackground(requireVPNConnection: false)
                        }
                        
                        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
                            DispatchQueue.main.async {
                                if importProgress < 1 {
                                    importProgress += 0.25
                                } else {
                                    t.invalidate()
                                    isImportingFile = false
                                    pairingFileIsValid = true
                                    withAnimation { showPairingFileMessage = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        withAnimation { showPairingFileMessage = false }
                                    }
                                }
                            }
                        }
                        RunLoop.current.add(progressTimer, forMode: .common)
                    } catch {
                        print("Error copying file: \(error)")
                    }
                }
                if accessing { url.stopAccessingSecurityScopedResource() }
            case .failure(let error):
                print("Failed to import file: \(error)")
            }
        }
        .sheet(isPresented: $isShowingInstalledApps) {
            InstalledAppsListView { selectedBundle in
                bundleID = selectedBundle
                isShowingInstalledApps = false
                HapticFeedbackHelper.trigger()
                
                var autoScriptData: Data? = nil
                var autoScriptName: String? = nil
                
                if let scriptInfo = preferredScript(for: selectedBundle) {
                    autoScriptData = scriptInfo.data
                    autoScriptName = scriptInfo.name
                }
                
                startJITInBackground(bundleID: selectedBundle,
                                     pid: nil,
                                     scriptData: autoScriptData,
                                     scriptName: autoScriptName,
                                     triggeredByURLScheme: false)
            }
        }
        .sheet(isPresented: $scriptViewShow) {
            NavigationView {
                if let jsModel {
                    RunJSView(model: jsModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { scriptViewShow = false }
                            }
                        }
                        .navigationTitle(selectedScript)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(isPresented: $showPIDSheet) {
            ConnectByPIDSheet(
                recentPIDs: $recentPIDs,
                onPasteCopyToast: { showCopiedToast() },
                onConnect: { pid in
                    HapticFeedbackHelper.trigger()
                    startJITInBackground(pid: pid)
                }
            )
        }
        .onOpenURL { url in
            guard let host = url.host else { return }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            switch host {
            case "enable-jit":
                var config = JITEnableConfiguration()
                if let pidStr = components?.queryItems?.first(where: { $0.name == "pid" })?.value, let pid = Int(pidStr) {
                    config.pid = pid
                }
                if let bundleId = components?.queryItems?.first(where: { $0.name == "bundle-id" })?.value {
                    config.bundleID = bundleId
                }
                if let scriptBase64URL = components?.queryItems?.first(where: { $0.name == "script-data" })?.value?.removingPercentEncoding {
                    let base64 = base64URLToBase64(scriptBase64URL)
                    if let scriptData = Data(base64Encoded: base64) {
                        config.scriptData = scriptData
                    }
                }
                if let scriptName = components?.queryItems?.first(where: { $0.name == "script-name" })?.value {
                    config.scriptName = scriptName
                }
                if config.scriptData == nil, let bundleID = config.bundleID,
                   let scriptInfo = preferredScript(for: bundleID) {
                    config.scriptData = scriptInfo.data
                    config.scriptName = scriptInfo.name
                }
                if viewDidAppeared {
                    startJITInBackground(bundleID: config.bundleID, pid: config.pid, scriptData: config.scriptData, scriptName: config.scriptName, triggeredByURLScheme: true)
                } else {
                    pendingJITEnableConfiguration = config
                }
            case "launch-app":
                if let bundleId = components?.queryItems?.first(where: { $0.name == "bundle-id" })?.value {
                    HapticFeedbackHelper.trigger()
                    DispatchQueue.global(qos: .userInitiated).async {
                        let success = JITEnableContext.shared.launchAppWithoutDebug(bundleId, logger: nil)
                        DispatchQueue.main.async {
                            let nameRaw = pinnedSystemAppNames[bundleId] ?? friendlyName(for: bundleId)
                            let name = shortDisplayName(from: nameRaw)
                            systemLaunchMessage = success
                            ? String(format: "Launch requested: %@".localized, name)
                            : String(format: "Failed to launch %@".localized, name)
                            scheduleSystemToastDismiss()
                        }
                    }
                }
            default:
                break
            }
        }
        .onAppear {
            viewDidAppeared = true
            if let config = pendingJITEnableConfiguration {
                startJITInBackground(bundleID: config.bundleID, pid: config.pid, scriptData: config.scriptData, scriptName: config.scriptName, triggeredByURLScheme: true)
                pendingJITEnableConfiguration = nil
            }
        }
    }
    
    // MARK: - Styled Sections
    
    private var welcomeCard: some View {
        homeCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingTitle)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                Text(greetingSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var setupCard: some View {
        homeCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Setup")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    connectionStatusBadge
                }
                
                statusLightsRow
                
                vpnControls
                
            }
        }
    }
    
    private var connectCard: some View {
        homeCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connect")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                if shouldPromptForWiFi {
                    statusBadge(
                        icon: "wifi.slash",
                        text: "Wi-Fi required",
                        color: .orange
                    )
                } else if pairingFileLikelyInvalid {
                    statusBadge(
                        icon: "xmark.octagon.fill",
                        text: "Pairing file expired",
                        color: .red
                    )
                }
                
                primaryActionControls
                
                if let info = connectionInfoMessage, !info.isEmpty {
                    Text(info)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if isImportingFile {
                    pairingImportProgressView
                } else if showPairingFileMessage && pairingFileIsValid {
                    pairingSuccessMessage
                }
            }
        }
    }
    
    // MARK: - Connection Setup Helpers
    
    @ViewBuilder
    private var connectionStatusBadge: some View {
        if isConnectionCheckRunning {
            statusBadge(icon: "clock.arrow.circlepath", text: "Checking…", color: .orange)
        } else if allStatusIndicatorsGreen {
            statusBadge(icon: "checkmark.circle.fill", text: "Ready", color: .green)
        } else if connectionHasError {
            statusBadge(icon: "exclamationmark.triangle.fill", text: "Needs attention", color: .yellow)
        } else {
            statusBadge(icon: "circle.lefthalf.filled", text: "Not ready", color: .yellow)
        }
    }
    
    private func statusBadge(icon: String, text: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.15))
            )
            .foregroundStyle(color)
    }
    
    private var connectionHasError: Bool {
        if case .failure = connectionCheckState { return true }
        if case .timeout = connectionCheckState { return true }
        return false
    }
    
    private var allStatusIndicatorsGreen: Bool {
        ddiIndicatorStatus == .success &&
        wifiIndicatorStatus == .success &&
        heartbeatIndicatorStatus == .success
    }
    
    private var statusLightsRow: some View {
        HStack(spacing: 12) {
            ForEach(statusLights) { light in
                if let action = light.action {
                    Button(action: action) {
                        StatusLightView(light: light)
                    }
                    .buttonStyle(.plain)
                    .disabled(!light.isEnabled)
                } else {
                    StatusLightView(light: light)
                }
            }
        }
    }
    
    private var statusLights: [StatusLightData] {
        [
            StatusLightData(
                type: .ddi,
                title: "DDI",
                icon: "externaldrive",
                status: ddiIndicatorStatus,
                detail: ddiDetailText
            ),
            StatusLightData(
                type: .wifi,
                title: "Wi-Fi",
                icon: "wifi",
                status: wifiIndicatorStatus,
                detail: wifiDetailText
            ),
            StatusLightData(
                type: .heartbeat,
                title: "Heartbeat",
                icon: "waveform.path.ecg",
                status: heartbeatIndicatorStatus,
                detail: heartbeatDetailText
            ),
            StatusLightData(
                type: .refresh,
                title: "Refresh",
                icon: "arrow.clockwise",
                status: refreshIndicatorStatus,
                detail: "",
                action: refreshStatusTapped,
                isEnabled: !isConnectionCheckRunning,
                indicatorIconName: "arrow.clockwise",
                indicatorColor: .blue,
                tintOverride: .blue
            )
        ]
    }
    
    private var ddiDetailText: String {
        if ddiMounted { return "Mounted" }
        if pairingFileLikelyInvalid { return "Error" }
        return pairingFileExists ? "Mount required" : "Not ready"
    }
    
    private var wifiDetailText: String {
        if isConnectionCheckRunning { return "Checking…" }
        return wifiConnected ? "Connected" : "Offline"
    }
    
    private var heartbeatDetailText: String {
        if heartbeatOK { return "Active" }
        if pairingFileExists {
            if requiresLoopbackVPN {
                return tunnel.tunnelStatus == .connected ? "Waiting" : "VPN required"
            } else {
                return "Waiting"
            }
        }
        return "Pair first"
    }
    
    private var refreshIndicatorStatus: StartupIndicatorStatus {
        switch connectionCheckState {
        case .running:
            return .running
        case .success:
            return .success
        case .failure, .timeout:
            return .warning
        case .idle:
            return .idle
        }
    }
    
    private var ddiIndicatorStatus: StartupIndicatorStatus {
        if ddiMounted { return .success }
        if pairingFileLikelyInvalid { return .warning }
        if pairingFileExists { return .warning }
        return .idle
    }
    
    private func color(for indicator: StartupIndicatorStatus) -> Color {
        indicator.tint
    }
    
    private func startWiFiMonitoring() {
        guard wifiMonitor == nil else { return }
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        wifiMonitor = monitor
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                wifiConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }
    
    private func stopWiFiMonitoring() {
        wifiMonitor?.cancel()
        wifiMonitor = nil
    }
    
    private func startCellularMonitoring() {
        guard cellularMonitor == nil else { return }
        let monitor = NWPathMonitor(requiredInterfaceType: .cellular)
        cellularMonitor = monitor
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                isCellularActive = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }
    
    private func stopCellularMonitoring() {
        cellularMonitor?.cancel()
        cellularMonitor = nil
        isCellularActive = false
    }
    
    private var pairingStatusDescription: String {
        if isValidatingPairingFile { return "Validating pairing file…" }
        if pairingFileExists {
            return "Pairing file imported and ready."
        }
        if pairingFilePresentOnDisk {
            return "We found a pairing file on disk but couldn’t read it. Import a new one."
        }
        return "Import the pairing file generated from your trusted computer."
    }
    
    private var wifiStatusDescription: String {
        if isConnectionCheckRunning { return "Checking Wi-Fi status…" }
        return wifiConnected ? "Wi-Fi connected and ready." : "Connect to Wi-Fi."
    }
    
    private var isConnectionCheckRunning: Bool {
        if case .running = connectionCheckState { return true }
        return false
    }
    
    private var vpnStatusSubtitle: String {
        if !requiresLoopbackVPN {
            return "External device selected. VPN tunnel not required."
        }
        if isConnectionCheckRunning {
            return "Checking the VPN/loopback tunnel…"
        }
        switch tunnel.tunnelStatus {
        case .connected:
            return "VPN is connected; loopback traffic is ready."
        case .connecting:
            return "Connecting… allow the VPN prompt if it appears."
        case .disconnecting:
            return "Disconnecting from the VPN."
        case .disconnected:
            return "VPN is off. Connect before running diagnostics."
        case .error:
            return "VPN configuration error. Try reconnecting."
        }
    }
    
    private var vpnIndicatorStatus: StartupIndicatorStatus {
        if !requiresLoopbackVPN { return .success }
        if isConnectionCheckRunning { return .running }
        switch tunnel.tunnelStatus {
        case .connected:
            return .success
        case .connecting, .disconnecting:
            return .running
        case .disconnected:
            return pairingFileExists ? .warning : .idle
        case .error:
            return .error
        }
    }
    
    private var wifiIndicatorStatus: StartupIndicatorStatus {
        if isConnectionCheckRunning { return .running }
        return wifiConnected ? .success : .warning
    }
    
    private var heartbeatSubtitle: String {
        if heartbeatOK {
            return "Heartbeat is responding."
        }
        if !requiresLoopbackVPN && pairingFileExists {
            return "Waiting for the remote device to respond."
        }
        if pairingFileLikelyInvalid {
            return "Heartbeat is blocked because the pairing file looks invalid."
        }
        if !pairingFileExists {
            return "Import a pairing file to start the heartbeat."
        }
        if case .running = connectionCheckState {
            return "Waiting for the connection check to finish."
        }
        if case .success = connectionCheckState {
            return "We’ll start heartbeat automatically—leave the app open."
        }
        return "Heartbeat runs after the connection check completes."
    }
    
    private var heartbeatIndicatorStatus: StartupIndicatorStatus {
        if heartbeatOK { return .success }
        if pairingFileLikelyInvalid { return .warning }
        if !pairingFileExists { return .idle }
        if case .running = connectionCheckState { return .running }
        if case .success = connectionCheckState { return .warning }
        return .idle
    }
    
    private var connectionCheckButtonLabel: some View {
        compactControlButton(
            icon: "waveform.path.ecg",
            title: isConnectionCheckRunning ? "Checking…" : "Run Check",
            showSpinner: isConnectionCheckRunning
        )
    }
    
    private var primaryActionControls: some View {
        VStack(spacing: 8) {
            Button(action: primaryActionTapped) {
                whiteCardButtonLabel(
                    icon: primaryActionIcon,
                    title: primaryActionTitle,
                    isLoading: isProcessing || isValidatingPairingFile
                )
            }
            .disabled(isProcessing || isValidatingPairingFile)
            
            if pairingFileExists && enableAdvancedOptions && !pairingFileLikelyInvalid && primaryActionTitle == "Connect by App" {
                Button(action: { showPIDSheet = true }) {
                    secondaryButtonLabel(icon: "number.circle", title: "Connect by PID")
                }
                .disabled(isProcessing)
            }
        }
    }
    
    @ViewBuilder
    private var vpnControls: some View {
        if !requiresLoopbackVPN {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("VPN Tunnel")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    statusBadge(icon: "checkmark.circle.fill", text: "Not needed", color: .green)
                }
                Text("You’re targeting an external device. StikDebug connects directly to \(DeviceConnectionContext.targetIPAddress).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("VPN Tunnel")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    statusBadge(icon: "shield.lefthalf.filled", text: tunnel.tunnelStatus.rawValue, color: vpnStatusColor)
                }
                
                Text(vpnStatusSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Button(action: { TunnelManager.shared.startVPN() }) {
                        compactControlButton(icon: "lock.open", title: "Connect")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStartVPN)
                    
                    Button(action: { TunnelManager.shared.stopVPN() }) {
                        compactControlButton(icon: "lock.fill", title: "Disconnect")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStopVPN)
                }
                
                Button {
                    autoStartVPN.toggle()
                    if requiresLoopbackVPN && autoStartVPN && tunnel.tunnelStatus == .disconnected {
                        TunnelManager.shared.startVPN()
                    }
                } label: {
                    compactControlButton(
                        icon: autoStartVPN ? "lock.circle" : "lock.slash",
                        title: autoStartVPN ? "Disable Auto VPN" : "Enable Auto VPN"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var vpnStatusColor: Color {
        if !requiresLoopbackVPN { return .green }
        switch tunnel.tunnelStatus {
        case .connected: return .green
            case .connecting, .disconnecting: return .orange
            case .error: return .red
            case .disconnected: return .yellow
            }
        }
        
        private var canStartVPN: Bool {
            guard requiresLoopbackVPN else { return false }
            switch tunnel.tunnelStatus {
            case .disconnected, .error:
                return true
            default:
                return false
            }
        }
        
        private var canStopVPN: Bool {
            guard requiresLoopbackVPN else { return false }
            switch tunnel.tunnelStatus {
            case .connected, .connecting, .disconnecting:
                return true
            default:
                return false
            }
        }
        
    private func refreshStatusTapped() {
        runConnectionDiagnostics()
        if pairingFileExists {
            startHeartbeatInBackground(requireVPNConnection: requiresLoopbackVPN)
        }
    }
    
    private func runConnectionDiagnostics(autoStart: Bool = false) {
        guard !isConnectionCheckRunning else { return }
            connectionTimeoutTask?.cancel()
            connectionTimeoutTask = nil
            connectionInfoMessage = autoStart ? "Checking connection…" : nil
            connectionCheckState = .running
            let timeout = DispatchWorkItem {
                DispatchQueue.main.async {
                    if case .running = connectionCheckState {
                        connectionCheckState = .timeout
                        connectionInfoMessage = requiresLoopbackVPN
                        ? "Connection timed out. Check the VPN and pairing file, then try again."
                        : "Connection timed out. Make sure the device at \(DeviceConnectionContext.targetIPAddress) is reachable."
                        connectionTimeoutTask = nil
                    }
                }
            }
            connectionTimeoutTask = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 7, execute: timeout)
            
            checkVPNConnection { success, error in
                connectionTimeoutTask?.cancel()
                connectionTimeoutTask = nil
                if success {
                    connectionCheckState = .success
                    connectionInfoMessage = nil
                    if pairingFileExists && !heartbeatOK {
                        startHeartbeatInBackground()
                    }
                } else {
                    let fallback = requiresLoopbackVPN ? "VPN tunnel is not connected." : "Unable to reach the device."
                    connectionCheckState = .failure(error ?? fallback)
                    connectionInfoMessage = error ?? fallback
                }
            }
        }
        
        private var primaryActionTitle: String {
            if isValidatingPairingFile { return "Validating…" }
            if !pairingFileExists { return pairingFilePresentOnDisk ? "Import New Pairing File" : "Import Pairing File" }
            if shouldPromptForWiFi { return "Connect to Wi-Fi" }
            if pairingFileLikelyInvalid { return "New Pairing File Needed" }
            if !ddiMounted { return "Mount Developer Disk Image" }
            return "Connect by App"
        }
        
        private var primaryActionIcon: String {
            if isValidatingPairingFile { return "hourglass" }
            if !pairingFileExists { return pairingFilePresentOnDisk ? "arrow.clockwise" : "doc.badge.plus" }
            if shouldPromptForWiFi { return "wifi.slash" }
            if pairingFileLikelyInvalid { return "arrow.clockwise" }
            if !ddiMounted { return "externaldrive" }
            return "cable.connector.horizontal"
        }
        
        private var pairingImportProgressView: some View {
            VStack(spacing: 8) {
                HStack {
                    Text("Processing pairing file…")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(importProgress * 100))%")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemFill))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accentColor)
                            .frame(width: geo.size.width * CGFloat(importProgress), height: 8)
                            .animation(.linear(duration: 0.25), value: importProgress)
                    }
                }
                .frame(height: 8)
            }
            .accessibilityElement(children: .combine)
        }
        
        private var pairingSuccessMessage: some View {
            HStack(spacing: 10) {
                StatusDot(color: .green)
                Text("Pairing file successfully imported")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.green)
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
            .transition(.opacity)
        }
        
        private func whiteCardButtonLabel(icon: String, title: String, isLoading: Bool = false) -> some View {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(accentColor.contrastText())
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                }
                
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundColor(accentColor.contrastText())
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        
        private func secondaryButtonLabel(icon: String, title: String) -> some View {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .foregroundStyle(.primary)
        }
        
        private var quickConnectCard: some View {
            homeCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text("Quick Connect")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        
                    }
                    
                    Text("Favorites and recents stay within reach so you can enable debug with ease.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    if quickConnectItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Pin apps from the Installed Apps list to see them here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                isShowingInstalledApps = true
                            } label: {
                                secondaryButtonLabel(icon: "star", title: "Choose Favorites")
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(quickConnectItems) { item in
                                QuickConnectRow(
                                    item: item,
                                    accentColor: accentColor,
                                    isEnabled: canConnectByApp && !isProcessing,
                                    action: {
                                        HapticFeedbackHelper.trigger()
                                        let scriptInfo = preferredScript(for: item.bundleID)
                                        startJITInBackground(bundleID: item.bundleID,
                                                             pid: nil,
                                                             scriptData: scriptInfo?.data,
                                                             scriptName: scriptInfo?.name,
                                                             triggeredByURLScheme: false)
                                    }
                                )
                            }
                        }
                    }
                    
                    if !canConnectByApp {
                        Text("Finish the pairing and mounting steps above to enable quick launches.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        
        private var launchShortcutsCard: some View {
            homeCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Launch Shortcuts".localized)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Pin any app from Installed Apps and launch it here with ease.".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 10) {
                        ForEach(pinnedLaunchItems) { item in
                            SystemPinnedRow(
                                item: item,
                                accentColor: accentColor,
                                isLaunching: launchingSystemApps.contains(item.bundleID),
                                action: { launchSystemApp(item: item) },
                                onRemove: { removePinnedSystemApp(bundleID: item.bundleID) }
                            )
                        }
                    }
                }
            }
        }
        
        private var quickConnectItems: [QuickConnectItem] {
            var seen = Set<String>()
            var ordered: [QuickConnectItem] = []
            for bundle in favoriteApps + recentApps {
                guard seen.insert(bundle).inserted else { continue }
                ordered.append(QuickConnectItem(bundleID: bundle, displayName: friendlyName(for: bundle)))
                if ordered.count >= 4 { break }
            }
            return ordered
        }
        
        private var pinnedLaunchItems: [SystemPinnedItem] {
            pinnedSystemApps.compactMap { bundleID in
                let raw = pinnedSystemAppNames[bundleID] ?? friendlyName(for: bundleID)
                let displayName = shortDisplayName(from: raw)
                return SystemPinnedItem(bundleID: bundleID, displayName: displayName)
            }
        }
        
        // Prefer CoreDevice-reported app name, trimmed to a Home Screen–style label; else fall back to bundle ID last component.
        private func friendlyName(for bundleID: String) -> String {
            if let cached = cachedAppNames[bundleID], !cached.isEmpty {
                return shortDisplayName(from: cached)
            }
            let components = bundleID.split(separator: ".")
            if let last = components.last {
                let cleaned = last.replacingOccurrences(of: "_", with: " ")
                let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed.capitalized }
            }
            return bundleID
        }
        
        // Heuristic “Home Screen” shortener for long marketing names.
        private func shortDisplayName(from name: String) -> String {
            var s = name
            
            // Keep only the part before common separators/subtitles.
            let separators = [" — ", " – ", " - ", ":", "|", "·", "•"]
            for sep in separators {
                if let r = s.range(of: sep) {
                    s = String(s[..<r.lowerBound])
                    break
                }
            }
            
            // Drop common suffixes like "for iPad", "for iOS"
            let suffixes = [
                " for iPhone", " for iPad", " for iOS", " for iPadOS",
                " iPhone", " iPad", " iOS", " iPadOS"
            ]
            for suf in suffixes {
                if s.localizedCaseInsensitiveContains(suf) {
                    s = s.replacingOccurrences(of: suf, with: "", options: [.caseInsensitive])
                }
            }
            
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? name : s
        }
        
        private func scheduleInitialSetupWork() {
            guard !isSchedulingInitialSetup else { return }
            isSchedulingInitialSetup = true
            
            let shouldRestoreCache = cachedAppNames.isEmpty
            let cachedData = cachedAppNamesData
            
            DispatchQueue.global(qos: .userInitiated).async {
                var restoredApps: [String: String]? = nil
                if shouldRestoreCache, let cachedData {
                    restoredApps = try? JSONDecoder().decode([String: String].self, from: cachedData)
                }
                
                DispatchQueue.main.async {
                    defer { isSchedulingInitialSetup = false }
                    
                    if let restoredApps, cachedAppNames.isEmpty {
                        cachedAppNames = restoredApps
                        syncFavoriteAppNamesWithCache()
                    }
                    
                    refreshBackground()
                    checkPairingFileExists()
                    loadAppListIfNeeded()
                    
                    if tunnel.tunnelStatus == .connected {
                        MountingProgress.shared.checkforMounted()
                    }
                }
            }
        }
        
        private func loadAppListIfNeeded(force: Bool = false) {
            guard pairingFileExists else {
                cachedAppNames = [:]
                cachedAppNamesData = nil
                return
            }
            
            guard tunnel.tunnelStatus == .connected else { return }
            
            if !force && !cachedAppNames.isEmpty { return }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let result = (try? JITEnableContext.shared.getAppList()) ?? [:]
                let encoded = try? JSONEncoder().encode(result)
                DispatchQueue.main.async {
                    cachedAppNames = result
                    syncFavoriteAppNamesWithCache()
                    cachedAppNamesData = encoded
                }
            }
        }
        
        private func homeCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
            content()
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        }
        
        private func compactControlButton(icon: String, title: String, showSpinner: Bool = false) -> some View {
            HStack(spacing: 6) {
                if showSpinner {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        
        private var tipsCard: some View {
            homeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tips")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    if !pairingFileExists {
                        tipRow(systemImage: "doc.badge.plus", title: "Pairing file required", message: "Import your device’s pairing file to begin.")
                    }
                    if pairingFileExists && !ddiMounted {
                        tipRow(systemImage: "externaldrive.badge.exclamationmark", title: "Developer Disk Image not mounted", message: "Ensure your pairing is imported and valid, connect to Wi-Fi and force-restart StikDebug.")
                    }
                    tipRow(systemImage: "lock.shield", title: "Local only", message: "StikDebug runs entirely on-device. No data leaves your device.")
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    Button {
                        if let url = URL(string: "https://github.com/StephenDev0/StikDebug-Guide/blob/main/pairing_file.md") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(accentColor)
                                .font(.system(size: 18, weight: .semibold))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pairing File Guide")
                                    .font(.subheadline.weight(.semibold))
                                Text("Step-by-step instructions from the community wiki.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        
        private func tipRow(systemImage: String, title: String, message: String) -> some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(accentColor)
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        
        private func primaryActionTapped() {
            guard !isValidatingPairingFile else { return }
            if pairingFileLikelyInvalid {
                if shouldPromptForWiFi {
                    showAlert(
                        title: "Wi-Fi Required",
                        message: "Connect to Wi-Fi.",
                        showOk: true
                    ) { _ in }
                } else {
                    isShowingPairingFilePicker = true
                }
                return
            }
            if pairingFileExists {
                if !ddiMounted {
                    showAlert(title: "Device Not Mounted".localized, message: "The Developer Disk Image has not been mounted yet. Check in settings for more information.".localized, showOk: true) { _ in }
                    return
                }
                isShowingInstalledApps = true
            } else {
                isShowingPairingFilePicker = true
            }
        }
        
        private func showCopiedToast() {
            withAnimation { justCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { justCopied = false }
            }
        }
        
        @ViewBuilder private func toast(_ text: String) -> some View {
            VStack {
                Spacer()
                Text(text)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 3)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 30)
            }
            .animation(.easeInOut(duration: 0.25), value: text)
        }
        
        private func checkPairingFileExists() {
            let fileExists = FileManager.default.fileExists(atPath: pairingFileURL.path)
            pairingFilePresentOnDisk = fileExists
            
            guard fileExists else {
                pairingFileExists = false
                lastValidatedPairingSignature = nil
                isValidatingPairingFile = false
                return
            }
            
            let signature = pairingFileSignature(for: pairingFileURL)
            
            guard needsValidation(for: signature) else { return }
            guard !isValidatingPairingFile else { return }
            
            isValidatingPairingFile = true
            
            DispatchQueue.global(qos: .utility).async {
                let valid = isPairing()
                DispatchQueue.main.async {
                    pairingFileExists = valid
                    lastValidatedPairingSignature = signature
                    isValidatingPairingFile = false
                }
            }
        }
        
        private func needsValidation(for signature: PairingFileSignature) -> Bool {
            guard let lastSignature = lastValidatedPairingSignature else { return true }
            return lastSignature != signature
        }
        
        
        private func pairingFileSignature(for url: URL) -> PairingFileSignature {
            let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
            let modificationDate = attributes[.modificationDate] as? Date
            let sizeValue = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
            return PairingFileSignature(modificationDate: modificationDate, fileSize: sizeValue)
        }
        private func refreshBackground() { }
        
        private func autoScript(for bundleID: String) -> (data: Data, name: String)? {
            guard ProcessInfo.processInfo.hasTXM else { return nil }
            guard #available(iOS 26, *) else { return nil }
            let appName = (try? JITEnableContext.shared.getAppList()[bundleID]) ?? storedFavoriteName(for: bundleID)
            guard let appName,
                  let resource = autoScriptResource(for: appName) else {
                return nil
            }
            let scriptsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("scripts")
            let documentsURL = scriptsDir.appendingPathComponent(resource.fileName)
            if let data = try? Data(contentsOf: documentsURL) {
                return (data, resource.fileName)
            }
            guard let bundleURL = Bundle.main.url(forResource: resource.resource, withExtension: "js"),
                  let data = try? Data(contentsOf: bundleURL) else {
                return nil
            }
            return (data, resource.fileName)
        }
        
        private func assignedScript(for bundleID: String) -> (data: Data, name: String)? {
            guard let mapping = UserDefaults.standard.dictionary(forKey: "BundleScriptMap") as? [String: String],
                  let scriptName = mapping[bundleID] else { return nil }
            let scriptsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("scripts")
            let scriptURL = scriptsDir.appendingPathComponent(scriptName)
            guard FileManager.default.fileExists(atPath: scriptURL.path),
                  let data = try? Data(contentsOf: scriptURL) else { return nil }
            return (data, scriptName)
        }
        
        private func preferredScript(for bundleID: String) -> (data: Data, name: String)? {
            if let assigned = assignedScript(for: bundleID) {
                return assigned
            }
            return autoScript(for: bundleID)
        }
        
        private func storedFavoriteName(for bundleID: String) -> String? {
            let defaults = UserDefaults(suiteName: "group.com.stik.sj")
            let names = defaults?.dictionary(forKey: "favoriteAppNames") as? [String: String]
            return names?[bundleID]
        }
        
        private func syncFavoriteAppNamesWithCache() {
            guard let sharedDefaults = UserDefaults(suiteName: "group.com.stik.sj") else { return }
            let favorites = sharedDefaults.stringArray(forKey: "favoriteApps") ?? []
            guard !favorites.isEmpty else { return }
            
            var storedNames = (sharedDefaults.dictionary(forKey: "favoriteAppNames") as? [String: String]) ?? [:]
            var changed = false
            
            for bundle in favorites {
                guard let rawName = cachedAppNames[bundle], !rawName.isEmpty else { continue }
                let display = shortDisplayName(from: rawName)
                if storedNames[bundle] != display {
                    storedNames[bundle] = display
                    changed = true
                }
            }
            
            if changed {
                sharedDefaults.set(storedNames, forKey: "favoriteAppNames")
                WidgetCenter.shared.reloadTimelines(ofKind: "FavoritesWidget")
            }
        }
        
        private func autoScriptResource(for appName: String) -> (resource: String, fileName: String)? {
            switch appName {
            case "maciOS":
                return ("maciOS", "maciOS.js")
            case "Amethyst":
                return ("Amethyst", "Amethyst.js")
            case "Geode":
                return ("Geode", "Geode.js")
            case "MeloNX":
                return ("MeloNX", "MeloNX.js")
            case "UTM", "DolphiniOS":
                return ("UTM-Dolphin", "UTM-Dolphin.js")
            default:
                return nil
            }
        }
        
        private func getJsCallback(_ script: Data, name: String? = nil) -> DebugAppCallback {
            return { pid, debugProxyHandle, remoteServerHandle, semaphore in
                jsModel = RunJSViewModel(pid: Int(pid),
                                         debugProxy: debugProxyHandle,
                                         remoteServer: remoteServerHandle,
                                         semaphore: semaphore)
                scriptViewShow = true
                DispatchQueue.global(qos: .background).async {
                    do { try jsModel?.runScript(data: script, name: name) }
                    catch { showAlert(title: "Error Occurred While Executing Script.".localized, message: error.localizedDescription, showOk: true) }
                }
            }
        }
        
        private func startJITInBackground(bundleID: String? = nil, pid : Int? = nil, scriptData: Data? = nil, scriptName: String? = nil, triggeredByURLScheme: Bool = false) {
            isProcessing = true
            LogManager.shared.addInfoLog("Starting Debug for \(bundleID ?? String(pid ?? 0))")
            
            DispatchQueue.global(qos: .background).async {
                var scriptData = scriptData
                var scriptName = scriptName
                if scriptData == nil,
                   let bundleID,
                   let preferred = preferredScript(for: bundleID) {
                    scriptName = preferred.name
                    scriptData = preferred.data
                }
                
                var callback: DebugAppCallback? = nil
                if ProcessInfo.processInfo.hasTXM, let sd = scriptData {
                    callback = getJsCallback(sd, name: scriptName ?? bundleID ?? "Script")
                    if triggeredByURLScheme { usleep(500000) }
                }
                
                let logger: LogFunc = { message in if let message { LogManager.shared.addInfoLog(message) } }
                var success: Bool
                if let pid {
                    success = JITEnableContext.shared.debugApp(withPID: Int32(pid), logger: logger, jsCallback: callback)
                    if success { DispatchQueue.main.async { addRecentPID(pid) } }
                } else if let bundleID {
                    success = JITEnableContext.shared.debugApp(withBundleID: bundleID, logger: logger, jsCallback: callback)
                } else {
                    DispatchQueue.main.async {
                        showAlert(title: "Failed to Debug App".localized, message: "Either bundle ID or PID should be specified.".localized, showOk: true)
                    }
                    success = false
                }
                
                if success {
                    DispatchQueue.main.async {
                        LogManager.shared.addInfoLog("Debug process completed for \(bundleID ?? String(pid ?? 0))")
                    }
                }
                isProcessing = false
            }
        }
        
        private func launchSystemApp(item: SystemPinnedItem) {
            guard !launchingSystemApps.contains(item.bundleID) else { return }
            launchingSystemApps.insert(item.bundleID)
            HapticFeedbackHelper.trigger()
            
            DispatchQueue.global(qos: .userInitiated).async {
                let success = JITEnableContext.shared.launchAppWithoutDebug(item.bundleID, logger: nil)
                
                DispatchQueue.main.async {
                    launchingSystemApps.remove(item.bundleID)
                    if success {
                        LogManager.shared.addInfoLog("Launch request sent for \(item.bundleID)")
                        systemLaunchMessage = String(format: "Launch requested: %@".localized, item.displayName)
                    } else {
                        LogManager.shared.addErrorLog("Failed to launch \(item.bundleID)")
                        systemLaunchMessage = String(format: "Failed to launch %@".localized, item.displayName)
                    }
                    scheduleSystemToastDismiss()
                }
            }
        }
        
        private func removePinnedSystemApp(bundleID: String) {
            Haptics.light()
            pinnedSystemApps.removeAll { $0 == bundleID }
            pinnedSystemAppNames.removeValue(forKey: bundleID)
            persistPinnedSystemApps()
        }
        
        private func scheduleSystemToastDismiss() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if systemLaunchMessage != nil {
                    withAnimation {
                        systemLaunchMessage = nil
                    }
                }
            }
        }
        
        private func persistPinnedSystemApps() {
            if let sharedDefaults = UserDefaults(suiteName: "group.com.stik.sj") {
                sharedDefaults.set(pinnedSystemApps, forKey: "pinnedSystemApps")
                sharedDefaults.set(pinnedSystemAppNames, forKey: "pinnedSystemAppNames")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        private func addRecentPID(_ pid: Int) {
            var list = recentPIDs.filter { $0 != pid }
            list.insert(pid, at: 0)
            if list.count > 8 { list = Array(list.prefix(8)) }
            recentPIDs = list
        }
        
        func base64URLToBase64(_ base64url: String) -> String {
            var base64 = base64url.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let pad = 4 - (base64.count % 4)
            if pad < 4 { base64 += String(repeating: "=", count: pad) }
            return base64
        }
        
        private struct StatusDot: View {
            var color: Color
            @Environment(\.colorScheme) private var colorScheme
            var body: some View {
                ZStack {
                    Circle().fill(color.opacity(0.25)).frame(width: 20, height: 20)
                    Circle().fill(color).frame(width: 12, height: 12)
                        .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 0)
                }
                .overlay(
                    Circle().stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 0.5)
                )
            }
        }
        
        private struct StatusGlyph: View {
            let icon: String
            let tint: Color
            var size: CGFloat = 48
            var iconSize: CGFloat = 22
            
            var body: some View {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: size, height: size)
                    
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(tint)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            }
        }
        
        private struct QuickConnectRow: View {
            let item: QuickConnectItem
            let accentColor: Color
            let isEnabled: Bool
            let action: () -> Void
            
            var body: some View {
                Button(action: action) {
                    HStack(spacing: 14) {
                        QuickAppBadge(title: item.displayName, accentColor: accentColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text(item.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .textSelection(.enabled)
                        }
                        
                        Spacer(minLength: 0)
                        
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isEnabled ? accentColor : Color.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground).opacity(isEnabled ? 0.65 : 0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.55)
            }
        }
        
        private struct SystemPinnedRow: View {
            let item: SystemPinnedItem
            let accentColor: Color
            let isLaunching: Bool
            var action: () -> Void
            var onRemove: () -> Void
            
            var body: some View {
                Button(action: action) {
                    HStack(spacing: 14) {
                        QuickAppBadge(title: item.displayName, accentColor: accentColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text(item.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .textSelection(.enabled)
                        }
                        
                        Spacer(minLength: 0)
                        
                        if isLaunching {
                            ProgressView()
                                .controlSize(.small)
                                .tint(accentColor)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLaunching)
                .contextMenu {
                    Button("Remove from Home".localized, systemImage: "star.slash") {
                        onRemove()
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Remove".localized, systemImage: "trash")
                    }
                }
            }
        }
        
        private struct QuickAppBadge: View {
            let title: String
            let accentColor: Color
            
            private var initials: String {
                let words = title.split(separator: " ")
                if let first = words.first, !first.isEmpty {
                    return String(first.prefix(1)).uppercased()
                }
                return String(title.prefix(1)).uppercased()
            }
            
            var body: some View {
                Text(initials)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accentColor.opacity(0.16))
                    )
                    .foregroundStyle(accentColor)
            }
        }
        
        private struct StatusLightView: View {
            let light: StatusLightData
            
            var body: some View {
                let tint = light.tintOverride ?? light.status.tint
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.18))
                            .frame(width: 48, height: 48)
                        Image(systemName: light.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            .frame(width: 48, height: 48)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: light.indicatorIconName ?? light.status.iconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(light.indicatorColor ?? light.status.symbolColor)
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 1)
                            )
                            .offset(x: 6, y: 6)
                    }
                    
                    VStack(spacing: 0) {
                        Text(light.title)
                            .font(.caption2.weight(.semibold))
                        Text(light.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 80)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(light.title) status")
                .accessibilityValue("\(light.detail). \(light.status.accessibilityDescription)")
            }
        }
        
        private struct StatusLightData: Identifiable {
            let id = UUID()
            let type: StatusLightType
            let title: String
            let icon: String
            let status: StartupIndicatorStatus
            let detail: String
            let action: (() -> Void)?
            let isEnabled: Bool
            let indicatorIconName: String?
            let indicatorColor: Color?
            let tintOverride: Color?
            
            init(type: StatusLightType,
                 title: String,
                 icon: String,
                 status: StartupIndicatorStatus,
                 detail: String,
                 action: (() -> Void)? = nil,
                 isEnabled: Bool = true,
                 indicatorIconName: String? = nil,
                 indicatorColor: Color? = nil,
                 tintOverride: Color? = nil) {
                self.type = type
                self.title = title
                self.icon = icon
                self.status = status
                self.detail = detail
                self.action = action
                self.isEnabled = isEnabled
                self.indicatorIconName = indicatorIconName
                self.indicatorColor = indicatorColor
                self.tintOverride = tintOverride
            }
        }
        
        private enum StatusLightType {
            case ddi
            case wifi
            case heartbeat
            case refresh
        }
        
        private struct PairingFileSignature: Equatable {
            let modificationDate: Date?
            let fileSize: UInt64
        }
        
        private enum ConnectionCheckState: Equatable {
            case idle
            case running
            case success
            case failure(String)
            case timeout
        }
        
        private enum StartupIndicatorStatus: Equatable {
            case idle
            case running
            case success
            case warning
            case error
            
            var iconName: String {
                switch self {
                case .success: return "checkmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .error: return "xmark.circle.fill"
                case .idle: return "circle"
                case .running: return "clock.arrow.circlepath"
                }
            }
            
            var tint: Color {
                switch self {
                case .success: return .green
                case .warning: return .yellow
                case .error: return .red
                case .idle: return .secondary
                case .running: return .orange
                }
            }
            
            var symbolColor: Color {
                switch self {
                case .success: return .green
                case .warning: return .orange
                case .error: return .red
                case .idle: return .secondary
                case .running: return .blue
                }
            }
            
            var accessibilityDescription: String {
                switch self {
                case .success: return "Success"
                case .warning: return "Warning"
                case .error: return "Error"
                case .idle: return "Idle"
                case .running: return "In progress"
                }
            }
        }
        private struct QuickConnectItem: Identifiable {
            let bundleID: String
            let displayName: String
            var id: String { bundleID }
        }
        
        private struct SystemPinnedItem: Identifiable {
            let bundleID: String
            let displayName: String
            var id: String { bundleID }
        }
        
        // MARK: - Connect-by-PID Sheet (minus/plus removed)
        
        private struct ConnectByPIDSheet: View {
            @Environment(\.dismiss) private var dismiss
            @Binding var recentPIDs: [Int]
            @State private var pidText: String = ""
            @State private var errorText: String? = nil
            @FocusState private var focused: Bool
            var onPasteCopyToast: () -> Void
            var onConnect: (Int) -> Void
            
            private var isValid: Bool {
                if let v = Int(pidText), v > 0 { return true }
                return false
            }
            
            private let capsuleHeight: CGFloat = 40
            
            var body: some View {
                NavigationView {
                    ZStack {
                        Color.clear.ignoresSafeArea()
                        
                        ScrollView {
                            VStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Enter a Process ID").font(.headline).foregroundColor(.primary)
                                    
                                    TextField("e.g. 1234", text: $pidText)
                                        .keyboardType(.numberPad)
                                        .textContentType(.oneTimeCode)
                                        .font(.system(.title3, design: .rounded))
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(.ultraThinMaterial)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                        .focused($focused)
                                        .onChange(of: pidText) { _, newVal in validate(newVal) }
                                    
                                    // Paste + Clear row
                                    HStack(spacing: 10) {
                                        CapsuleButton(systemName: "doc.on.clipboard", title: "Paste", height: capsuleHeight) {
                                            if let n = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                                               let v = Int(n), v > 0 {
                                                pidText = String(v)
                                                validate(pidText)
                                                onPasteCopyToast()
                                            } else {
                                                errorText = "No valid PID on the clipboard."
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                        }
                                        
                                        CapsuleButton(systemName: "xmark", title: "Clear", height: capsuleHeight) {
                                            pidText = ""
                                            errorText = nil
                                        }
                                    }
                                    
                                    
                                    if let errorText {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill").font(.footnote)
                                            Text(errorText).font(.footnote)
                                        }
                                        .foregroundColor(.orange)
                                        .transition(.opacity)
                                    }
                                    
                                    if !recentPIDs.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Recents")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.secondary)
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(recentPIDs, id: \.self) { pid in
                                                        Button {
                                                            pidText = String(pid); validate(pidText)
                                                        } label: {
                                                            Text("#\(pid)")
                                                                .font(.footnote.weight(.semibold))
                                                                .padding(.vertical, 6)
                                                                .padding(.horizontal, 10)
                                                                .background(
                                                                    Capsule(style: .continuous)
                                                                        .fill(Color(UIColor.tertiarySystemBackground))
                                                                )
                                                        }
                                                        .contextMenu {
                                                            Button(role: .destructive) {
                                                                removeRecent(pid)
                                                            } label: { Label("Remove", systemImage: "trash") }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    Button {
                                        guard let pid = Int(pidText), pid > 0 else { return }
                                        onConnect(pid)
                                        addRecent(pid)
                                        dismiss()
                                    } label: {
                                        HStack {
                                            Image(systemName: "bolt.horizontal.circle").font(.system(size: 20))
                                            Text("Connect")
                                                .font(.system(.title3, design: .rounded))
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .foregroundColor(Color.accentColor.contrastText())
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                        )
                                    }
                                    .disabled(!isValid)
                                    .padding(.top, 8)
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 30)
                        }
                    }
                    .navigationTitle("Connect by PID")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
                    .onAppear { focused = true }
                }
            }
            
            // Small glassy square icon button
            private func iconSquareButton(systemName: String, action: @escaping () -> Void) -> some View {
                Button(action: action) {
                    Image(systemName: systemName)
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(UIColor.tertiarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            
            private func validate(_ text: String) {
                if text.isEmpty { errorText = nil; return }
                if Int(text) == nil || Int(text)! <= 0 { errorText = "Please enter a positive number." }
                else { errorText = nil }
            }
            private func addRecent(_ pid: Int) {
                var list = recentPIDs.filter { $0 != pid }
                list.insert(pid, at: 0)
                if list.count > 8 { list = Array(list.prefix(8)) }
                recentPIDs = list
            }
            private func removeRecent(_ pid: Int) { recentPIDs.removeAll { $0 == pid } }
            private func prefillFromClipboardIfPossible() {
                if let s = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let v = Int(s), v > 0 {
                    pidText = String(v); errorText = nil
                }
            }
            
            @ViewBuilder private func CapsuleButton(systemName: String, title: String, height: CGFloat = 40, action: @escaping () -> Void) -> some View {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: systemName)
                        Text(title).font(.subheadline.weight(.semibold))
                    }
                    .frame(height: height) // enforce uniform height
                    .padding(.horizontal, 12)
                    .background(Capsule(style: .continuous).fill(Color(UIColor.tertiarySystemBackground)))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        
    }

// MARK: - TXM detection

public extension ProcessInfo {
    var hasTXM: Bool {
        if isTXMOverridden {
            return true
        }
        if DeviceLibraryStore.shared.isUsingExternalDevice {
            return DeviceLibraryStore.shared.activeDevice?.isTXM ?? false
        }
        return ProcessInfo.detectLocalTXM()
    }
    
    var isTXMOverridden: Bool {
        UserDefaults.standard.bool(forKey: UserDefaults.Keys.txmOverride)
    }
    
    private static func detectLocalTXM() -> Bool {
        if let boot = FileManager.default.filePath(atPath: "/System/Volumes/Preboot", withLength: 36),
           let file = FileManager.default.filePath(atPath: "\(boot)/boot", withLength: 96) {
            return access("\(file)/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0
        } else {
            return (FileManager.default.filePath(atPath: "/private/preboot", withLength: 96).map {
                access("\($0)/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0
            }) ?? false
        }
    }
}
