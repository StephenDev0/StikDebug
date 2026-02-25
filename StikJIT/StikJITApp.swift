//
//  StikJITApp.swift
//  StikJIT
//
//  Created by Stephen on 3/26/25.
//

import SwiftUI
import Network
import UniformTypeIdentifiers

// Register default settings before the app starts
private func registerAdvancedOptionsDefault() {
    let os = ProcessInfo.processInfo.operatingSystemVersion
    // Enable advanced options by default on iOS 19/26 and above
    let enabled = os.majorVersion >= 19
    UserDefaults.standard.register(defaults: ["enableAdvancedOptions": enabled])
    UserDefaults.standard.register(defaults: [UserDefaults.Keys.txmOverride: false])
    UserDefaults.standard.register(defaults: ["keepAliveAudio": true])
    UserDefaults.standard.register(defaults: ["keepAliveLocation": true])
}

// MARK: - DNS Checker

class DNSChecker: ObservableObject {
    @Published var appleIP: String?
    @Published var controlIP: String?
    @Published var dnsError: String?
    
    func checkDNS() {
        checkIfConnectedToWifi { [weak self] wifiConnected in
            guard let self = self else { return }
            if wifiConnected {
                let group = DispatchGroup()
                
                group.enter()
                self.lookupIPAddress(for: "gs.apple.com") { ip in
                    DispatchQueue.main.async {
                        self.appleIP = ip
                    }
                    group.leave()
                }
                
                group.enter()
                self.lookupIPAddress(for: "google.com") { ip in
                    DispatchQueue.main.async {
                        self.controlIP = ip
                    }
                    group.leave()
                }
                
                group.notify(queue: .main) {
                    if self.controlIP == nil {
                        self.dnsError = "No internet connection."
                    } else if self.appleIP == nil {
                        self.dnsError = "Apple DNS blocked. Your network might be filtering Apple traffic."
                    } else {
                        self.dnsError = nil
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.dnsError = nil
                }
            }
        }
    }
    
    private func checkIfConnectedToWifi(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor.pathUpdateHandler = { path in
            completion(path.status == .satisfied)
            monitor.cancel()
        }
        let queue = DispatchQueue.global(qos: .background)
        monitor.start(queue: queue)
    }
    
    private func lookupIPAddress(for host: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            var hints = addrinfo(
                ai_flags: 0,
                ai_family: AF_UNSPEC,
                ai_socktype: SOCK_STREAM,
                ai_protocol: 0,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil
            )
            var res: UnsafeMutablePointer<addrinfo>?
            let err = getaddrinfo(host, nil, &hints, &res)
            if err != 0 {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            var ipAddress: String?
            var ptr = res
            while ptr != nil {
                if let addr = ptr?.pointee.ai_addr {
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, ptr!.pointee.ai_addrlen,
                                   &hostBuffer, socklen_t(hostBuffer.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        ipAddress = String(cString: hostBuffer)
                        break
                    }
                }
                ptr = ptr?.pointee.ai_next
            }
            freeaddrinfo(res)
            DispatchQueue.main.async { completion(ipAddress) }
        }
    }
}

// MARK: - Main App

// Global state variable for the heartbeat response.
var pubHeartBeat = false
private var heartbeatStartPending = false
private var heartbeatStartInProgress = false
private var heartbeatPendingShowUI = true

@main
struct HeartbeatApp: App {
    @StateObject private var mount = MountingProgress.shared
    @Environment(\.scenePhase) private var scenePhase   // Observe scene lifecycle
    @State private var shouldAttemptHeartbeatRestart = false
    
    init() {
        registerAdvancedOptionsDefault()
        if UserDefaults.standard.bool(forKey: "keepAliveAudio") {
            BackgroundAudioManager.shared.start()
        }
        if UserDefaults.standard.bool(forKey: "keepAliveLocation") {
            BackgroundLocationManager.shared.start()
        }
        if let fixMethod  = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.fix_init(forOpeningContentTypes:asCopy:))),
           let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:))) {
            method_exchangeImplementations(origMethod, fixMethod)
        }
        
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            shouldAttemptHeartbeatRestart = true
        case .active:
            if shouldAttemptHeartbeatRestart {
                shouldAttemptHeartbeatRestart = false
                startHeartbeatInBackground(showErrorUI: false)
            }
        default:
            break
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    Task {
                        let fileManager = FileManager.default
                        for item in ddiDownloadItems {
                            let destinationURL = URL.documentsDirectory.appendingPathComponent(item.relativePath)
                            if fileManager.fileExists(atPath: destinationURL.path) { continue }
                            do {
                                try await downloadFile(from: item.urlString, to: destinationURL)
                            } catch {
                                await MainActor.run {
                                    showAlert(title: "An Error has Occurred",
                                              message: "[Download DDI Error]: \(error.localizedDescription)",
                                              showOk: true)
                                }
                                break
                            }
                        }
                    }
                }
            .onChange(of: scenePhase) { newPhase in
                handleScenePhaseChange(newPhase)
            }
        }

    }
}

// MARK: - Additional Helpers

actor FunctionGuard<T> {
    private var runningTask: Task<T, Never>?
    
    func execute(_ work: @escaping @Sendable () -> T) async -> T {
        if let task = runningTask {
            return await task.value
        }
        let task = Task.detached { work() }
        runningTask = task
        let result = await task.value
        runningTask = nil
        return result
    }
}

class MountingProgress: ObservableObject {
    static var shared = MountingProgress()
    @Published var mountProgress: Double = 0.0
    @Published var mountingThread: Thread?
    @Published var coolisMounted: Bool = false
    
    func checkforMounted() {
        DispatchQueue.global(qos: .utility).async {
            let mounted = isMounted()
            DispatchQueue.main.async {
                self.coolisMounted = mounted
            }
        }
    }
    
    func progressCallback(progress: size_t, total: size_t, context: UnsafeMutableRawPointer?) {
        let percentage = Double(progress) / Double(total) * 100.0
        DispatchQueue.main.async {
            self.mountProgress = percentage
        }
    }
    
    func pubMount() {
        mount()
    }
    
    private func mount() {
        let currentlyMounted = isMounted()
        DispatchQueue.main.async {
            self.coolisMounted = currentlyMounted
        }

        if isPairing(), !currentlyMounted {
            if let mountingThread = mountingThread {
                mountingThread.cancel()
                self.mountingThread = nil
            }
            
            let thread = Thread { [weak self] in
                guard let self = self else { return }
                let mountError = mountPersonalDDI(
                    imagePath: URL.documentsDirectory.appendingPathComponent("DDI/Image.dmg").path,
                    trustcachePath: URL.documentsDirectory.appendingPathComponent("DDI/Image.dmg.trustcache").path,
                    manifestPath: URL.documentsDirectory.appendingPathComponent("DDI/BuildManifest.plist").path,
                )

                DispatchQueue.main.async {
                    if let mountError {
                        showAlert(title: "DDI Mount Failed", message: mountError, showOk: true, showTryAgain: true) { shouldTryAgain in
                            if shouldTryAgain { self.mount() }
                        }
                    } else {
                        self.coolisMounted = true
                        self.checkforMounted()
                    }
                    self.mountingThread = nil
                }
            }
            thread.qualityOfService = .background
            thread.name = "mounting"
            thread.start()
            mountingThread = thread
        }
    }
}

func isPairing() -> Bool {
    let pairingpath = URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path
    var pairingFile: IdevicePairingFile?
    let err = idevice_pairing_file_read(pairingpath, &pairingFile)
    if err != nil { return false }
    idevice_pairing_file_free(pairingFile)
    return true
}

func startHeartbeatInBackground(showErrorUI: Bool = true) {
    assert(Thread.isMainThread, "startHeartbeatInBackground must be called on the main thread")
    let pairingFileURL = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
    
    guard FileManager.default.fileExists(atPath: pairingFileURL.path) else {
        heartbeatStartPending = false
        heartbeatPendingShowUI = true
        return
    }
    
    guard !heartbeatStartInProgress else {
        return
    }
    
    heartbeatStartPending = false
    heartbeatPendingShowUI = true
    heartbeatStartInProgress = true
    
    DispatchQueue.global(qos: .userInteractive).async {
        defer {
            DispatchQueue.main.async {
                heartbeatStartInProgress = false
            }
        }
        do {
            try JITEnableContext.shared.startHeartbeat()
            LogManager.shared.addInfoLog("Heartbeat started successfully")
            pubHeartBeat = true
            
            DispatchQueue.main.async {
                let trustcachePath = URL.documentsDirectory.appendingPathComponent("DDI/Image.dmg.trustcache").path
                guard FileManager.default.fileExists(atPath: trustcachePath),
                      !MountingProgress.shared.coolisMounted,
                      MountingProgress.shared.mountingThread == nil else { return }
                MountingProgress.shared.pubMount()
            }
        } catch {
            let err2 = error as NSError
            let code = err2.code
            LogManager.shared.addErrorLog("\(error.localizedDescription) (Code: \(code))")
            guard showErrorUI else { return }
            DispatchQueue.main.async {
                if code == -9 {
                    do {
                        try FileManager.default.removeItem(at: URL.documentsDirectory.appendingPathComponent("pairingFile.plist"))
                        LogManager.shared.addInfoLog("Removed invalid pairing file")
                    } catch {
                        LogManager.shared.addErrorLog("Failed to remove invalid pairing file: \(error.localizedDescription)")
                    }
                    
                    showAlert(
                        title: "Invalid Pairing File",
                        message: "The pairing file is invalid or expired. Please select a new pairing file.",
                        showOk: true,
                        showTryAgain: false,
                        primaryButtonText: "Select New File"
                    ) { _ in
                        NotificationCenter.default.post(name: NSNotification.Name("ShowPairingFilePicker"), object: nil)
                    }
                } else {
                    showAlert(
                        title: "Heartbeat Error",
                        message: "\(error.localizedDescription)\n\nMake sure Wi‑Fi and LocalDevVPN are connected and that the device is reachable.",
                        showOk: false,
                        showTryAgain: true
                    ) { shouldTryAgain in
                        if shouldTryAgain {
                            DispatchQueue.main.async {
                                startHeartbeatInBackground()
                            }
                        }
                    }
                }
            }
        }
    }
    

}

func checkDeviceConnection(callback: @escaping (Bool, String?) -> Void) {
    let targetIP = DeviceConnectionContext.targetIPAddress
    let host = NWEndpoint.Host(targetIP)
    let port = NWEndpoint.Port(rawValue: 62078)!
    let connection = NWConnection(host: host, port: port, using: .tcp)
    var timeoutWorkItem: DispatchWorkItem?
    
    timeoutWorkItem = DispatchWorkItem { [weak connection] in
        if connection?.state != .ready {
            connection?.cancel()
            DispatchQueue.main.async {
                if timeoutWorkItem?.isCancelled == false {
                    let message = "[TIMEOUT] Could not reach the device at \(targetIP). Make sure it’s online and on the same network."
                    callback(false, message)
                }
            }
        }
    }
    
    connection.stateUpdateHandler = { [weak connection] state in
        switch state {
        case .ready:
            timeoutWorkItem?.cancel()
            connection?.cancel()
            DispatchQueue.main.async {
                callback(true, nil)
            }
        case .failed(let error):
            timeoutWorkItem?.cancel()
            connection?.cancel()
            DispatchQueue.main.async {
                let message = "Could not reach the device at \(targetIP): \(error.localizedDescription)"
                callback(false, message)
            }
        default:
            break
        }
    }
    
    connection.start(queue: .global())
    if let workItem = timeoutWorkItem {
        DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: workItem)
    }
}

public func showAlert(title: String, message: String, showOk: Bool, showTryAgain: Bool = false, primaryButtonText: String? = nil, completion: ((Bool) -> Void)? = nil) {
    DispatchQueue.main.async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if showTryAgain {
            alert.addAction(UIAlertAction(title: primaryButtonText ?? "Try Again", style: .default) { _ in
                completion?(true)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completion?(false)
            })
        } else if showOk {
            alert.addAction(UIAlertAction(title: primaryButtonText ?? "OK", style: .default) { _ in
                completion?(true)
            })
        } else {
             alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completion?(true)
            })
        }
        
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        topController.present(alert, animated: true)
    }
}

private struct DDIDownloadItem {
    let name: String
    let relativePath: String
    let urlString: String
}

private let ddiDownloadItems: [DDIDownloadItem] = [
    .init(
        name: "Build Manifest",
        relativePath: "DDI/BuildManifest.plist",
        urlString: "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized/BuildManifest.plist"
    ),
    .init(
        name: "Image",
        relativePath: "DDI/Image.dmg",
        urlString: "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized/Image.dmg"
    ),
    .init(
        name: "TrustCache",
        relativePath: "DDI/Image.dmg.trustcache",
        urlString: "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized/Image.dmg.trustcache"
    )
]

enum DDIDownloadError: LocalizedError {
    case invalidURL(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let string):
            return "Invalid download URL: \(string)"
        }
    }
}

func downloadFile(from urlString: String, to destinationURL: URL) async throws {
    guard let url = URL(string: urlString) else {
        throw DDIDownloadError.invalidURL(urlString)
    }
    let (tempLocalUrl, _) = try await URLSession.shared.download(from: url)
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
    if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
    }
    try fileManager.moveItem(at: tempLocalUrl, to: destinationURL)
}

func redownloadDDI(progressHandler: ((Double, String) -> Void)? = nil) async throws {
    let fileManager = FileManager.default
    let totalStages = Double(ddiDownloadItems.count + 1)
    var completedStages = 0.0
    
    progressHandler?(0.0, "Removing existing DDI files…")
    for item in ddiDownloadItems {
        let fileURL = URL.documentsDirectory.appendingPathComponent(item.relativePath)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    completedStages += 1.0
    progressHandler?(completedStages / totalStages, "Starting downloads…")
    
    for item in ddiDownloadItems {
        progressHandler?(completedStages / totalStages, "Downloading \(item.name)…")
        let destinationURL = URL.documentsDirectory.appendingPathComponent(item.relativePath)
        try await downloadFile(from: item.urlString, to: destinationURL)
        completedStages += 1.0
        progressHandler?(completedStages / totalStages, "\(item.name) ready")
    }
    progressHandler?(1.0, "DDI download complete.")
}
