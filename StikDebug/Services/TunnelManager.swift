//
//  TunnelManager.swift
//  StikDebug
//

import Foundation

final class TunnelManager: ObservableObject {
    static let shared = TunnelManager()

    @Published private(set) var isConnected = false

    private var isStarting = false
    private var pathChangeWorkItem: DispatchWorkItem?

    private init() {
        // Reconnect when the network path changes (e.g. a Wi-Fi↔cellular handoff)
        // so the tunnel comes back instead of staying dropped. Block-based
        // observer avoids needing an @objc selector on this non-NSObject singleton.
        NotificationCenter.default.addObserver(
            forName: .networkPathDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.networkPathChanged()
        }
    }

    func markDisconnected() {
        runOnMain {
            self.isConnected = false
        }
    }

    func start(showErrorUI: Bool = true) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.start(showErrorUI: showErrorUI)
            }
            return
        }

        let pairingFileURL = PairingFileStore.prepareURL()
        guard FileManager.default.fileExists(atPath: pairingFileURL.path) else {
            isConnected = false
            return
        }

        guard !isStarting else {
            return
        }

        isStarting = true

        DispatchQueue.global(qos: .userInteractive).async { [showErrorUI] in
            let result = self.connectWithRetry()

            DispatchQueue.main.async {
                self.finishStart(result, showErrorUI: showErrorUI)
            }
        }
    }

    /// Attempts the tunnel connection a few times with a short backoff before
    /// giving up. Cellular paths (and Wi-Fi↔cellular handoffs) are more prone to
    /// transient connect failures than Wi-Fi, so a couple of retries turn a
    /// spurious drop into a successful connection instead of an error alert.
    private func connectWithRetry() -> Result<Void, NSError> {
        let maxAttempts = 3
        var lastError: NSError?

        for attempt in 1...maxAttempts {
            do {
                try JITEnableContext.shared.startTunnel()
                if attempt > 1 {
                    LogManager.shared.addInfoLog("Tunnel connected on attempt \(attempt)")
                }
                return .success(())
            } catch let error as NSError {
                lastError = error

                if Self.isPermanentTunnelError(error) || attempt == maxAttempts {
                    break
                }

                let backoff = TimeInterval(attempt) // 1s, then 2s
                LogManager.shared.addWarningLog(
                    "Tunnel connect attempt \(attempt) failed: \(error.localizedDescription). Retrying in \(Int(backoff))s…"
                )
                Thread.sleep(forTimeInterval: backoff)
            }
        }

        return .failure(lastError ?? NSError(
            domain: "StikDebug",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Tunnel connection failed"]
        ))
    }

    /// True for failures that another attempt won't fix — they need user action
    /// (fresh pairing file, valid target IP), not a retry.
    private static func isPermanentTunnelError(_ error: NSError) -> Bool {
        // -9 invalid/expired pairing, -17 missing pairing, -18 bad target IP.
        if [-9, -17, -18].contains(error.code) {
            return true
        }
        let message = error.localizedDescription.lowercased()
        return message.contains("parse target ip")
            || message.contains("pairing file not found")
    }

    private func networkPathChanged() {
        // Debounce: a handoff can emit several path updates in quick succession.
        pathChangeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.handleNetworkPathChange()
        }
        pathChangeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private func handleNetworkPathChange() {
        let status = NetworkPathMonitor.shared.status
        guard status.isReachable else { return }

        // Re-establish the primary tunnel if it dropped during the change.
        guard !isConnected else { return }
        LogManager.shared.addInfoLog("Network path changed (\(status.description)); reconnecting tunnel")
        start(showErrorUI: false)
    }

    private func finishStart(_ result: Result<Void, NSError>, showErrorUI: Bool) {
        isStarting = false

        switch result {
        case .success:
            isConnected = true
            LogManager.shared.addInfoLog("Tunnel connected successfully")
            mountDeveloperDiskImageIfNeeded()
        case .failure(let error):
            isConnected = false
            handleStartFailure(error, showErrorUI: showErrorUI)
        }
    }

    private func mountDeveloperDiskImageIfNeeded() {
        let trustcachePath = URL.documentsDirectory.appendingPathComponent("DDI/Image.dmg.trustcache").path
        guard FileManager.default.fileExists(atPath: trustcachePath),
              !MountingProgress.shared.coolisMounted,
              MountingProgress.shared.mountingThread == nil else {
            return
        }
        MountingProgress.shared.pubMount()
    }

    private func handleStartFailure(_ error: NSError, showErrorUI: Bool) {
        LogManager.shared.addErrorLog(tunnelConnectionLogMessage(for: error))
        guard showErrorUI else {
            return
        }

        if error.code == -9 {
            handleInvalidPairingFile()
            return
        }

        showAlert(
            title: "Connection Error",
            message: tunnelConnectionAlertMessage(for: error),
            showOk: false,
            showTryAgain: true
        ) { shouldTryAgain in
            if shouldTryAgain {
                startTunnelInBackground()
            }
        }
    }

    private func handleInvalidPairingFile() {
        LogManager.shared.addInfoLog("Pairing file reported invalid; keeping existing file")

        showAlert(
            title: "Invalid Pairing File",
            message: "The pairing file may be invalid or expired. You can import a new pairing file to replace it.",
            showOk: true,
            showTryAgain: false,
            primaryButtonText: "Select New File"
        ) { _ in
            NotificationCenter.default.post(name: NSNotification.Name("ShowPairingFilePicker"), object: nil)
        }
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

func startTunnelInBackground(showErrorUI: Bool = true) {
    TunnelManager.shared.start(showErrorUI: showErrorUI)
}

func markTunnelDisconnected() {
    TunnelManager.shared.markDisconnected()
}

private func tunnelConnectionLogMessage(for error: NSError) -> String {
    let target = "\(DeviceConnectionContext.targetIPAddress):49152"
    return "Tunnel connection failed for \(target): \(error.localizedDescription) (Domain: \(error.domain), Code: \(error.code), Raw: \(String(describing: error)))"
}

private func tunnelConnectionAlertMessage(for error: NSError) -> String {
    let targetIP = DeviceConnectionContext.targetIPAddress
    let rawMessage = error.localizedDescription
    let lowercasedMessage = rawMessage.lowercased()

    let likelyCause: String
    let recoverySteps: [String]

    if error.code == 48 || lowercasedMessage.contains("address already in use") || lowercasedMessage.contains("port already in use") {
        likelyCause = "A port needed for the tunnel is already in use."
        recoverySteps = [
            "Close other JIT, debugging, proxy, or VPN apps that may be using the tunnel.",
            "Disconnect and reconnect LocalDevVPN.",
            "Restart StikDebug, then try again.",
            "If it keeps happening, reboot the device to clear the stuck port."
        ]
    } else if error.code == 54 || lowercasedMessage.contains("connection reset") {
        likelyCause = "The device or VPN closed the tunnel connection before setup finished."
        recoverySteps = [
            "Open LocalDevVPN and confirm the VPN is connected.",
            "Make sure LocalDevVPN is using the default \(DeviceConnectionContext.defaultTargetIPAddress) address.",
            "Reconnect LocalDevVPN, then try again (Wi-Fi or cellular both work).",
            "If this keeps happening, select a fresh pairing file."
        ]
    } else if error.code == -18 || lowercasedMessage.contains("parse target ip") {
        likelyCause = "The configured target IP address is not valid."
        recoverySteps = [
            "Open Settings and check the target IP address.",
            "Use the default \(DeviceConnectionContext.defaultTargetIPAddress)."
        ]
    } else if lowercasedMessage.contains("timed out") || lowercasedMessage.contains("timeout") {
        likelyCause = "The app could not reach the device before the connection timed out."
        recoverySteps = [
            "Confirm you have network access (Wi-Fi or cellular) and LocalDevVPN is connected.",
            "Wake and unlock the target device.",
            "Confirm LocalDevVPN is exposing the device at \(targetIP)."
        ]
    } else if lowercasedMessage.contains("network is unreachable") || lowercasedMessage.contains("no route") {
        likelyCause = "The VPN route to the device is not available."
        recoverySteps = [
            "Disconnect and reconnect LocalDevVPN.",
            "Confirm iOS shows the VPN indicator.",
            "Toggle your network connection (or Airplane Mode) off and on."
        ]
    } else {
        likelyCause = "The tunnel could not be created."
        recoverySteps = [
            "Confirm network access (Wi-Fi or cellular) and LocalDevVPN are connected.",
            "Wake and unlock the target device.",
            "Reconnect LocalDevVPN, then try again."
        ]
    }

    let steps = recoverySteps.enumerated()
        .map { "\($0.offset + 1). \($0.element)" }
        .joined(separator: "\n")

    return """
    \(likelyCause)

    Target: \(targetIP):49152
    Expected LocalDevVPN IP: \(DeviceConnectionContext.defaultTargetIPAddress)

    Try this:
    \(steps)

    Technical details:
    Code \(error.code): \(rawMessage)
    """
}
