//
//  PairingController.swift
//  StikDebug
//

import BackgroundTasks
import Foundation
import StikPairFFI
import UserNotifications

@MainActor
final class PairingController: ObservableObject {
    static let shared = PairingController()
    nonisolated static let taskIdentifier = (Bundle.main.bundleIdentifier ?? "com.stik.stikdebug") + ".pairing"

    enum Phase: Equatable {
        case idle
        case waiting
        case showPin(String)
        case success(PairedDevice)
        case failed(String)
    }

    struct PairedDevice: Equatable {
        var name: String
        var model: String
        var udid: String
        var pairingFilePath: String

        var pairingFileURL: URL {
            URL(fileURLWithPath: pairingFilePath)
        }
    }

    @Published var phase: Phase = .idle

    @Published var keepAliveAudio: Bool = UserDefaults.standard.object(forKey: Defaults.keepAliveAudioKey) as? Bool ?? true {
        didSet { UserDefaults.standard.set(keepAliveAudio, forKey: Defaults.keepAliveAudioKey) }
    }

    @Published var keepAliveLocation: Bool = UserDefaults.standard.object(forKey: Defaults.keepAliveLocationKey) as? Bool ?? false {
        didSet { UserDefaults.standard.set(keepAliveLocation, forKey: Defaults.keepAliveLocationKey) }
    }

    private enum Defaults {
        static let keepAliveAudioKey = "pairingKeepAliveAudio"
        static let keepAliveLocationKey = "pairingKeepAliveLocation"
    }

    private let bindAddress = "0.0.0.0"
    private let hostName = "StikPair"
    private var netService: NetService?
    private let localNetwork = PairingLocalNetworkAuthorization()

    private var bgTask: BGTask?
    private var pairingStarted = false
    private var taskFinished = false
    private var requestedAudioKeepAlive = false
    private var requestedLocationKeepAlive = false

    var isSystemSupported: Bool {
        if #available(iOS 27.0, *) {
            return true
        }
        return false
    }

    var isRunning: Bool {
        switch phase {
        case .waiting, .showPin:
            return true
        default:
            return false
        }
    }

    nonisolated static func registerBackgroundTask() {
        guard #available(iOS 26.0, *) else { return }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: PairingController.taskIdentifier,
            using: DispatchQueue.main
        ) { task in
            MainActor.assumeIsolated {
                PairingController.shared.runPairing(task: task)
            }
        }
    }

    func start() {
        guard !isRunning else { return }

        guard isSystemSupported else {
            phase = .failed("On-device wireless pairing requires iOS 27 or later.")
            return
        }

        phase = .waiting
        requestNotifications()
        startKeepAlive()

        Task {
            guard await localNetwork.request() else {
                stopKeepAlive()
                phase = .failed("Local Network permission is required. Enable it in Settings, then try again.")
                return
            }

            submitBackgroundTask()
        }
    }

    func reset() {
        guard !isRunning else { return }
        phase = .idle
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func startKeepAlive() {
        if keepAliveAudio {
            BackgroundAudioManager.shared.requestStart(force: true)
            requestedAudioKeepAlive = true
        }

        if keepAliveLocation {
            BackgroundLocationManager.shared.requestStart(force: true)
            requestedLocationKeepAlive = true
        }
    }

    private func stopKeepAlive() {
        if requestedAudioKeepAlive {
            BackgroundAudioManager.shared.requestStop(force: true)
            requestedAudioKeepAlive = false
        }

        if requestedLocationKeepAlive {
            BackgroundLocationManager.shared.requestStop(force: true)
            requestedLocationKeepAlive = false
        }
    }

    private func submitBackgroundTask() {
        guard #available(iOS 26.0, *) else {
            runPairing(task: nil)
            return
        }

        let request = BGContinuedProcessingTaskRequest(
            identifier: PairingController.taskIdentifier,
            title: "StikPair",
            subtitle: "Waiting for a device to connect...")
        request.strategy = .queue

        do {
            try BGTaskScheduler.shared.submit(request)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, !self.pairingStarted else { return }
                self.runPairing(task: nil)
            }
        } catch {
            runPairing(task: nil)
        }
    }

    private func runPairing(task: BGTask?) {
        guard !pairingStarted else { return }
        pairingStarted = true
        taskFinished = false
        bgTask = task
        configureBackgroundTask(task)

        let bind = bindAddress
        let name = hostName
        let outPath = Self.temporaryPairingFileURL().path
        try? FileManager.default.removeItem(atPath: outPath)

        let ctxBits = UInt(bitPattern: Unmanaged.passRetained(self).toOpaque())

        DispatchQueue.global(qos: .userInitiated).async {
            let ctx = UnsafeMutableRawPointer(bitPattern: ctxBits)
            var result = StikPairResult()
            let rc = bind.withCString { bindC in
                name.withCString { nameC in
                    "Mac17,7".withCString { modelC in
                        outPath.withCString { outC in
                            stikpair_run_host(
                                bindC,
                                0,
                                nameC,
                                modelC,
                                outC,
                                readyCallback,
                                pinCallback,
                                ctx,
                                &result
                            )
                        }
                    }
                }
            }

            let outcome: Phase
            let completedSuccessfully: Bool

            if rc == 0 {
                let generatedPath = cString(result.pairing_file_path)
                do {
                    try PairingFileStore.replace(with: URL(fileURLWithPath: generatedPath))
                    try? FileManager.default.removeItem(atPath: generatedPath)
                    outcome = .success(PairedDevice(
                        name: cString(result.device_name),
                        model: cString(result.device_model),
                        udid: cString(result.device_udid),
                        pairingFilePath: PairingFileStore.url.path
                    ))
                    completedSuccessfully = true
                } catch {
                    outcome = .failed("Pairing completed, but StikDebug could not save the pairing file: \(error.localizedDescription)")
                    completedSuccessfully = false
                }
            } else {
                let message = cString(result.error)
                outcome = .failed(message.isEmpty ? "Pairing failed (code \(rc))." : message)
                completedSuccessfully = false
            }

            stikpair_result_free(&result)
            if let ctx {
                Unmanaged<PairingController>.fromOpaque(ctx).release()
            }

            DispatchQueue.main.async {
                self.stopAdvertising()
                self.stopKeepAlive()
                self.pairingStarted = false
                self.phase = outcome

                if case .success = outcome {
                    self.updateTaskProgress(100)
                    self.postReturnNotification()
                    NotificationCenter.default.post(name: .pairingFileImported, object: nil)
                    markTunnelDisconnected()
                    startTunnelInBackground(showErrorUI: false)
                }

                self.finishTask(success: completedSuccessfully)
            }
        }
    }

    private func configureBackgroundTask(_ task: BGTask?) {
        guard let task else { return }

        updateTaskProgress(5)
        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.stopKeepAlive()
                self.finishTask(success: false)
                if self.isRunning {
                    self.phase = .failed("Background time expired before a device connected. Tap Pair to try again.")
                }
            }
        }
    }

    private func updateTaskProgress(_ completedUnitCount: Int64) {
        guard #available(iOS 26.0, *),
              let task = bgTask as? BGContinuedProcessingTask else {
            return
        }

        task.progress.totalUnitCount = 100
        task.progress.completedUnitCount = completedUnitCount
    }

    private func updateTaskTitle(subtitle: String) {
        guard #available(iOS 26.0, *),
              let task = bgTask as? BGContinuedProcessingTask else {
            return
        }

        task.updateTitle("StikPair", subtitle: subtitle)
    }

    private func finishTask(success: Bool) {
        guard !taskFinished else { return }
        taskFinished = true
        bgTask?.setTaskCompleted(success: success)
        bgTask = nil
    }

    fileprivate func startAdvertising(serviceID: String, port: Int32, txt: [String: Data]) {
        stopAdvertising()

        let service = NetService(
            domain: "",
            type: "_remotepairing-pairable-host._tcp.",
            name: serviceID,
            port: port
        )
        service.setTXTRecord(NetService.data(fromTXTRecord: txt))
        service.publish()
        netService = service
    }

    fileprivate func presentPin(_ pin: String) {
        phase = .showPin(pin)
        updateTaskProgress(50)
        updateTaskTitle(subtitle: "Enter code \(pin) on this device")

        if keepAliveAudio || keepAliveLocation {
            notify(
                id: "stikdebug.pairing.pin",
                title: "StikPair pairing code",
                body: "Enter \(pin) on this device to pair."
            )
        }
    }

    private func stopAdvertising() {
        netService?.stop()
        netService = nil
    }

    private func postReturnNotification() {
        notify(
            id: "stikdebug.pairing.done",
            title: "Pairing complete",
            body: "Return to StikDebug to use the new pairing file."
        )
    }

    private func notify(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func temporaryPairingFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("stikdebug-rp-\(UUID().uuidString).plist")
    }
}

private let readyCallback: StikPairReadyCb = { ctx, serviceID, port, keys, vals, count in
    guard let ctx, let serviceID else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    let id = String(cString: serviceID)

    var txt: [String: Data] = [:]
    if let keys, let vals {
        for index in 0..<Int(count) {
            guard let key = keys[index], let value = vals[index] else { continue }
            txt[String(cString: key)] = Data(String(cString: value).utf8)
        }
    }

    DispatchQueue.main.async {
        controller.startAdvertising(serviceID: id, port: Int32(port), txt: txt)
    }
}

private let pinCallback: StikPairPinCb = { pin, ctx in
    guard let ctx, let pin else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    let pinString = String(cString: pin)

    DispatchQueue.main.async {
        controller.presentPin(pinString)
    }
}

private func cString(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
    guard let ptr else { return "" }
    return String(cString: ptr)
}
