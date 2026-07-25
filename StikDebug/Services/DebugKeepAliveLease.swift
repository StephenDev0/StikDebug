//
//  DebugKeepAliveLease.swift
//  StikDebug
//

import Foundation
import UIKit

/// Keeps StikDebug running in the background for the duration of a debug/JIT
/// session so the debug connection (and its heartbeat) survives being switched
/// out of the app — e.g. while playing a JIT-enabled game. If iOS suspends the
/// app, that connection goes idle and the device tears it down, which is what
/// makes the target app lose its session/JIT after a while.
final class DebugKeepAliveLease {
    private let stateLock = NSLock()
    private var isActive = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    init() {
        activate()
    }

    func invalidate() {
        stateLock.lock()
        guard isActive else {
            stateLock.unlock()
            return
        }
        isActive = false
        stateLock.unlock()

        runOnMain {
            // Forced holds so the session stays alive even if the user turned the
            // keep-alive toggles off; released here when the session ends.
            BackgroundAudioManager.shared.requestStop(force: true)
            BackgroundLocationManager.shared.requestStop(force: true)
            self.endBackgroundTask()
        }
    }

    private func activate() {
        stateLock.lock()
        guard !isActive else {
            stateLock.unlock()
            return
        }
        isActive = true
        stateLock.unlock()

        runOnMain {
            BackgroundAudioManager.shared.requestStart(force: true)
            BackgroundLocationManager.shared.requestStart(force: true)
            self.beginBackgroundTask()
        }
    }

    // MARK: - Background task (main-thread only)

    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "StikDebugDebugSession") { [weak self] in
            guard let self else { return }
            // The silent-audio keep-alive is what actually sustains background
            // execution, so do NOT tear the session down when this assertion
            // expires (the old behaviour, which dropped long sessions). Release
            // the expiring task and take a fresh one so the session keeps running.
            self.stateLock.lock()
            let stillActive = self.isActive
            self.stateLock.unlock()

            if stillActive {
                LogManager.shared.addInfoLog("Debug session background window renewed (keep-alive continues)")
                self.beginBackgroundTask()
            } else {
                self.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }
}
