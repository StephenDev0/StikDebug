//
//  ContentView.swift
//  StikJIT
//
//  Created by Stephen on 3/26/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct JITEnableConfiguration {
    var bundleID: String? = nil
    var pid : Int? = nil
    var scriptData: Data? = nil
    var scriptName : String? = nil
}

struct HomeView: View {

    @AppStorage("username") private var username = "User"
    @AppStorage("autoQuitAfterEnablingJIT") private var doAutoQuitAfterEnablingJIT = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @AppStorage("bundleID") private var bundleID: String = ""
    @State private var isProcessing = false
    @State private var isShowingInstalledApps = false
    @State private var isShowingPairingFilePicker = false
    @State private var pairingFileExists: Bool = false
    @State private var showPairingFileMessage = false
    @State private var pairingFileIsValid = false
    @State private var isImportingFile = false
    @State private var importProgress: Float = 0.0
    
    @State private var viewDidAppeared = false
    @State private var pendingJITEnableConfiguration : JITEnableConfiguration? = nil
    
    @State var scriptViewShow = false
    @State private var isShowingConsole = false
    @AppStorage("DefaultScriptName") var selectedScript = "attachDetach.js"
    @State var jsModel: RunJSViewModel?
    @ObservedObject private var mounting = MountingProgress.shared


    var body: some View {
        ZStack {
            VStack(spacing: 25) {
                Spacer()
                VStack(spacing: 5) {
                    Text("Welcome to StikDebug \(username)!")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text(pairingFileExists ? "Click enable JIT to get started" : "Pick pairing file to get started")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Main action button - changes based on whether we have a pairing file
                Button(action: {
                    
                    
                    if pairingFileExists {
                        // Refresh heartbeat
                        pubHeartBeat = false
                        startHeartbeatInBackground()

                        // Got a pairing file, check mount status
                        let mountStatus = checkMountStatus()
                        if mountStatus == .notMounted {
                            showAlert(title: "Device Not Mounted", message: "The Developer Disk Image has not been mounted yet. Check in settings for more information.", showOk: true) { cool in
                                // No Need
                            }
                            return
                        } else if mountStatus == .unreachable {
                            // Don't show a separate error here — the heartbeat
                            // will fail and show its own connectivity error.
                            return
                        }

                        isShowingInstalledApps = true
                        
                    } else {
                        // No pairing file yet, let's get one
                        isShowingPairingFilePicker = true
                    }
                }) {
                    HStack {
                        Image(systemName: pairingFileExists ? "bolt.fill" : "doc.badge.plus")
                            .font(.system(size: 20))
                        Text(pairingFileExists ? "Enable JIT" : "Select Pairing File")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)

                Button(action: {
                    isShowingConsole = true
                }) {
                    HStack {
                        Image(systemName: "terminal")
                            .font(.system(size: 20))
                        Text("Open Console")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)

                // Status message area - keeps layout consistent
                ZStack {
                    // Progress bar for importing file
                    if isImportingFile {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Processing pairing file...")
                                    .font(.system(.caption, design: .rounded))
                                Spacer()
                                Text("\(Int(importProgress * 100))%")
                                    .font(.system(.caption, design: .rounded))
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.black.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(width: geometry.size.width * CGFloat(importProgress), height: 8)
                                        .animation(.linear(duration: 0.3), value: importProgress)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    // Success message
                    if showPairingFileMessage && pairingFileIsValid {
                        Text("✓ Pairing file successfully imported")
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .transition(.opacity)
                    }
                    
                    // Invisible text to reserve space - no layout jumps
                    Text(" ").opacity(0)
                }
                .frame(height: isImportingFile ? 60 : 30)  // Adjust height based on what's showing
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            checkPairingFileExists()
            startHeartbeatInBackground()
            MountingProgress.shared.checkforMounted()
        }
        .onReceive(NotificationCenter.default.publisher(for: .intentJSScriptReady)) { notification in
            guard let model = notification.userInfo?["model"] as? RunJSViewModel else { return }
            jsModel = model
            if let name = notification.userInfo?["scriptName"] as? String {
                selectedScript = name
            }
            scriptViewShow = true
        }
        .onReceive(timer) { _ in
            checkPairingFileExists()
            if mounting.mountingThread == nil && !mounting.coolisMounted {
                MountingProgress.shared.checkforMounted()
            }
        }
        .fileImporter(isPresented: $isShowingPairingFilePicker, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!, UTType(filenameExtension: "mobiledevicepair", conformingTo: .data)!, .propertyList]) {result in
            switch result {
            
            case .success(let url):
                let fileManager = FileManager.default
                let accessing = url.startAccessingSecurityScopedResource()
                
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        if fileManager.fileExists(atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path) {
                            try fileManager.removeItem(at: URL.documentsDirectory.appendingPathComponent("pairingFile.plist"))
                        }
                        
                        try fileManager.copyItem(at: url, to: URL.documentsDirectory.appendingPathComponent("pairingFile.plist"))
                        print("File copied successfully!")
                        
                        // Show progress bar and initialize progress
                        DispatchQueue.main.async {
                            isImportingFile = true
                            importProgress = 0.0
                            pairingFileExists = true
                        }
                        
                        startHeartbeatInBackground()
                        
                        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                            DispatchQueue.main.async {
                                if importProgress < 1.0 {
                                    importProgress += 0.25
                                } else {
                                    timer.invalidate()
                                    isImportingFile = false
                                    pairingFileIsValid = true
                                    
                                    // Show success message
                                    withAnimation {
                                        showPairingFileMessage = true
                                    }
                                    
                                    // Hide message after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        withAnimation {
                                            showPairingFileMessage = false
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Ensure timer keeps running
                        RunLoop.current.add(progressTimer, forMode: .common)
                        
                    } catch {
                        print("Error copying file: \(error)")
                    }
                } else {
                    print("Source file does not exist.")
                }
                
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("Failed to import file: \(error)")
            }
        }
        .sheet(isPresented: $isShowingInstalledApps) {
            InstalledAppsListView { selectedBundle in
                bundleID = selectedBundle
                isShowingInstalledApps = false
                HapticFeedbackHelper.trigger()
                startJITInBackground(bundleID: selectedBundle)
            }
        }
        .onOpenURL { url in
            guard let host = url.host() else { return }
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
            case "kill-process":
                if let pidStr = components?.queryItems?.first(where: { $0.name == "pid" })?.value, let pid = Int(pidStr) {
                    pubHeartBeat = false
                    startHeartbeatInBackground(showErrorUI: false)
                    DispatchQueue.global(qos: .userInitiated).async {
                        sleep(1)
                        do {
                            try JITEnableContext.shared.killProcess(withPID: Int32(pid))
                            DispatchQueue.main.async {
                                LogManager.shared.addInfoLog("Killed process \(pid) via URL scheme")
                            }
                        } catch {
                            DispatchQueue.main.async {
                                LogManager.shared.addErrorLog("Failed to kill process \(pid): \(error.localizedDescription)")
                            }
                        }
                    }
                }
            case "launch-app":
                if let bundleId = components?.queryItems?.first(where: { $0.name == "bundle-id" })?.value {
                    HapticFeedbackHelper.trigger()
                    DispatchQueue.global(qos: .userInitiated).async {
                        let _ = JITEnableContext.shared.launchAppWithoutDebug(bundleId, logger: nil)
                    }
                }
            default:
                break
            }
        }
        .onAppear() {
            viewDidAppeared = true
            if let config = pendingJITEnableConfiguration {
                startJITInBackground(bundleID: config.bundleID, pid: config.pid, scriptData: config.scriptData, scriptName: config.scriptName, triggeredByURLScheme: true)
                pendingJITEnableConfiguration = nil
            }
        }
        .sheet(isPresented: $isShowingConsole) {
            NavigationStack {
                ConsoleLogsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                isShowingConsole = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $scriptViewShow) {
            NavigationStack {
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
    }
    

    
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
    
    private func autoScriptResource(for appName: String) -> (resource: String, fileName: String)? {
        switch appName {
        case "maciOS":
            return ("maciOS", "maciOS.js")
        case "Amethyst", "MeloNX":
            return ("Amethyst-MeloNX", "Amethyst-MeloNX.js")
        case "Geode":
            return ("Geode", "Geode.js")
        case "Manic EMU":
            return ("manic", "manic.js")
        case "UTM", "DolphiniOS", "Flycast":
            return ("UTM-Dolphin", "UTM-Dolphin.js")
        default:
            return nil
        }
    }
    
    private func getJsCallback(_ script: Data, name: String? = nil) -> DebugAppCallback {
        return { pid, debugProxyHandle, remoteServerHandle, semaphore in
            let model = RunJSViewModel(pid: Int(pid),
                                       debugProxy: debugProxyHandle,
                                       remoteServer: remoteServerHandle,
                                       semaphore: semaphore)
            
            DispatchQueue.main.async {
                jsModel = model
                scriptViewShow = true
            }
            
            DispatchQueue.global(qos: .background).async {
                do { try model.runScript(data: script, name: name) }
                catch { showAlert(title: "Error Occurred While Executing Script.".localized, message: error.localizedDescription, showOk: true) }
            }
        }
    }
    
    private func checkPairingFileExists() {
        pairingFileExists = FileManager.default.fileExists(atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path)
    }
    
    private func startJITInBackground(bundleID: String? = nil, pid: Int? = nil, scriptData: Data? = nil, scriptName: String? = nil, triggeredByURLScheme: Bool = false) {
        isProcessing = true
        LogManager.shared.addInfoLog("Starting Debug for \(bundleID ?? String(pid ?? 0))")

        if triggeredByURLScheme {
            pubHeartBeat = false
            startHeartbeatInBackground(showErrorUI: false)
        }

        DispatchQueue.global(qos: .background).async {

            if triggeredByURLScheme {
                sleep(1)
            }
            let finishProcessing = {
                DispatchQueue.main.async {
                    isProcessing = false
                }
            }

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
            }

            let logger: LogFunc = { message in if let message { LogManager.shared.addInfoLog(message) } }
            var success: Bool
            if let pid {
                success = JITEnableContext.shared.debugApp(withPID: Int32(pid), logger: logger, jsCallback: callback)
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

                    if doAutoQuitAfterEnablingJIT {
                        exit(0)
                    }
                }
            }
            finishProcessing()
        }
    }

    private func base64URLToBase64(_ base64url: String) -> String {
        var base64 = base64url.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let pad = 4 - (base64.count % 4)
        if pad < 4 { base64 += String(repeating: "=", count: pad) }
        return base64
    }
}

#Preview {
    HomeView()
}

public extension ProcessInfo {
    var hasTXM: Bool {
        if isTXMOverridden {
            return true
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
