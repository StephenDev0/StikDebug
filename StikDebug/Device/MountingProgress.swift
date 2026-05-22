//
//  MountingProgress.swift
//  StikDebug
//

import Foundation
import idevice

final class MountingProgress: ObservableObject {
    static let shared = MountingProgress()

    @Published private(set) var mountProgress: Double = 0.0
    @Published private(set) var mountingThread: Thread?
    @Published private(set) var coolisMounted: Bool = false

    private init() {}

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

        guard isPairing(), !currentlyMounted else {
            return
        }

        if let mountingThread {
            mountingThread.cancel()
            self.mountingThread = nil
        }

        let thread = Thread { [weak self] in
            guard let self else { return }
            let mountError = mountPersonalDDI(
                imagePath: URL.documentsDirectory.appendingPathComponent("DDI/Image.dmg").path,
                trustcachePath: URL.documentsDirectory.appendingPathComponent("DDI/Image.dmg.trustcache").path,
                manifestPath: URL.documentsDirectory.appendingPathComponent("DDI/BuildManifest.plist").path
            )

            DispatchQueue.main.async {
                if let mountError {
                    showAlert(title: "DDI Mount Failed", message: mountError, showOk: true, showTryAgain: true) { shouldTryAgain in
                        if shouldTryAgain {
                            self.mount()
                        }
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

func isPairing() -> Bool {
    let pairingPath = PairingFileStore.prepareURL().path
    var pairingFile: RpPairingFileHandle?
    let error = rp_pairing_file_read(pairingPath, &pairingFile)
    if error != nil {
        return false
    }
    rp_pairing_file_free(pairingFile)
    return true
}
