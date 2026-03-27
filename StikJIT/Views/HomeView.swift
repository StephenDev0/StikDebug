//
//  ContentView.swift
//  StikJIT
//
//  Created by Stephen on 3/26/25.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct JITEnableConfiguration {
    var bundleID: String? = nil
    var pid : Int? = nil
    var scriptData: Data? = nil
    var scriptName : String? = nil
}

struct HomeView: View {

    @AppStorage("autoQuitAfterEnablingJIT") private var doAutoQuitAfterEnablingJIT = false
    @AppStorage("bundleID") private var bundleID: String = ""
    @State private var isProcessing = false
    @State private var viewDidAppeared = false
    @State private var pendingJITEnableConfiguration : JITEnableConfiguration? = nil
    @State private var isShowingPairingFilePicker = false

    @State var scriptViewShow = false
    @State private var isShowingConsole = false
    @AppStorage("DefaultScriptName") var selectedScript = "attachDetach.js"
    @State var jsModel: RunJSViewModel?
    @ObservedObject private var mounting = MountingProgress.shared

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        InstalledAppsListView(onSelectApp: { selectedBundle in
            bundleID = selectedBundle
            HapticFeedbackHelper.trigger()
            startJITInBackground(bundleID: selectedBundle)
        }, showDoneButton: false, onImportPairingFile: { isShowingPairingFilePicker = true })
        .onAppear {
            startTunnelInBackground()
            MountingProgress.shared.checkforMounted()
            viewDidAppeared = true
            if let config = pendingJITEnableConfiguration {
                startJITInBackground(bundleID: config.bundleID, pid: config.pid, scriptData: config.scriptData, scriptName: config.scriptName, triggeredByURLScheme: true)
                pendingJITEnableConfiguration = nil
            }
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
            if mounting.mountingThread == nil && !mounting.coolisMounted {
                MountingProgress.shared.checkforMounted()
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
                    pubTunnelConnected = false
                    startTunnelInBackground(showErrorUI: false)
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
        .fileImporter(isPresented: $isShowingPairingFilePicker, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!, UTType(filenameExtension: "mobiledevicepair", conformingTo: .data)!, .propertyList]) { result in
            switch result {
            case .success(let url):
                let fileManager = FileManager.default
                let accessing = url.startAccessingSecurityScopedResource()
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        let dest = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
                        if fileManager.fileExists(atPath: dest.path) {
                            try fileManager.removeItem(at: dest)
                        }
                        try fileManager.copyItem(at: url, to: dest)
                        pubTunnelConnected = false
                        startTunnelInBackground()
                        NotificationCenter.default.post(name: .pairingFileImported, object: nil)
                        // Dismiss any existing connection error alert
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            var top = root
                            while let presented = top.presentedViewController { top = presented }
                            if top is UIAlertController { top.dismiss(animated: true) }
                        }
                    } catch {
                        print("Error copying pairing file: \(error)")
                    }
                }
                if accessing { url.stopAccessingSecurityScopedResource() }
            case .failure(let error):
                print("Failed to import pairing file: \(error)")
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
        case "Amethyst", "MeloNX", "XeniOS", "MeloCafe":
            return ("universal", "universal.js")
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

    private func startJITInBackground(bundleID: String? = nil, pid: Int? = nil, scriptData: Data? = nil, scriptName: String? = nil, triggeredByURLScheme: Bool = false) {
        isProcessing = true
        LogManager.shared.addInfoLog("Starting Debug for \(bundleID ?? String(pid ?? 0))")
        BackgroundLocationManager.shared.requestStart()

        if triggeredByURLScheme {
            pubTunnelConnected = false
            startTunnelInBackground(showErrorUI: false)
        }

        DispatchQueue.global(qos: .background).async {

            if triggeredByURLScheme {
                sleep(1)
            }
            let finishProcessing = {
                DispatchQueue.main.async {
                    isProcessing = false
                    BackgroundLocationManager.shared.requestStop()
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
