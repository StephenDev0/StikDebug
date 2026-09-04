//
//  LocationSimulationKeepAlive.swift
//  StikDebug
//

import CoreLocation
import Foundation
import UIKit

/// Owns the lifetime of an active simulated location, independently of any view.
///
/// The device drops a simulated location if nothing keeps pushing it, so the
/// coordinate has to be re-sent periodically. That resend loop used to live in
/// `LocationSimulationView`'s `@State` as a main-runloop `Timer`, torn down by
/// `.onDisappear` — which tied the simulation's lifetime to the map screen being
/// visible and the app being foregrounded. Leaving the map tab, locking the
/// phone, or roughly thirty seconds of background were each enough to stop the
/// resends, let the simulation connection die, and snap the device back to its
/// real location.
///
/// This keeps the coordinate outside the view, resends it from a dispatch timer
/// rather than the main runloop, holds the keep-alive services for as long as a
/// simulation is active, and renews its background assertion instead of letting
/// it expire.
final class LocationSimulationKeepAlive {
    static let shared = LocationSimulationKeepAlive()

    /// The device drops the simulation if it goes unrefreshed; this matches the
    /// interval the view's timer used.
    private static let resendInterval: TimeInterval = 4

    /// Remembers the held coordinate across launches, so a location survives the
    /// app being killed or the device rebooting.
    private static let storageKey = "heldSimulatedLocation"

    private let stateLock = NSLock()
    private let timerQueue = DispatchQueue(label: "com.stik.location-keepalive")

    private var coordinate: CLLocationCoordinate2D?
    private var timer: DispatchSourceTimer?
    private var isHolding = false
    private var consecutiveResendFailures = 0

    /// Main-thread only, mirroring `DebugKeepAliveLease`.
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    var isActive: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return coordinate != nil
    }

    var activeCoordinate: CLLocationCoordinate2D? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return coordinate
    }

    /// Begin holding `newCoordinate`, or retarget an existing hold.
    ///
    /// Safe to call repeatedly: the keep-alive is acquired once and the resend
    /// timer is created once, no matter how many times the coordinate changes.
    func hold(_ newCoordinate: CLLocationCoordinate2D) {
        stateLock.lock()
        let isFirstHold = coordinate == nil
        coordinate = newCoordinate
        if isFirstHold {
            consecutiveResendFailures = 0
        }
        stateLock.unlock()

        persist(newCoordinate)
        acquireKeepAlive()
        startTimer()

        if isFirstHold {
            LogManager.shared.addInfoLog("Holding simulated location (resending every \(Int(Self.resendInterval))s)")
        }
    }

    /// Re-arm a location that was still held when the app last stopped running.
    ///
    /// iOS gives sideloaded apps no way to launch themselves, so a reboot or a
    /// kill always ends the simulation. The next best thing is to pick it straight
    /// back up on launch: the resend loop tolerates failures, so this can be armed
    /// before LocalDevVPN is connected and will take hold once it is.
    func restoreIfNeeded() {
        guard !isActive else { return }

        guard let values = UserDefaults.standard.array(forKey: Self.storageKey) as? [Double],
              values.count == 2 else {
            return
        }

        let restored = CLLocationCoordinate2D(latitude: values[0], longitude: values[1])
        guard CLLocationCoordinate2DIsValid(restored) else {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
            return
        }

        // Without a pairing file nothing can ever succeed, and retrying forever
        // would just burn battery.
        guard FileManager.default.fileExists(atPath: PairingFileStore.prepareURL().path) else {
            return
        }

        LogManager.shared.addInfoLog(
            String(format: "Restoring held simulated location: %.6f, %.6f", restored.latitude, restored.longitude)
        )
        hold(restored)
    }

    private func persist(_ value: CLLocationCoordinate2D?) {
        if let value {
            UserDefaults.standard.set([value.latitude, value.longitude], forKey: Self.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
    }

    /// Stop holding a simulated location and release the keep-alive.
    ///
    /// This does **not** clear the simulation on the device — callers that want
    /// the real location back must still call `clear_simulated_location()`.
    func release() {
        stateLock.lock()
        let wasActive = coordinate != nil
        coordinate = nil
        timer?.cancel()
        timer = nil
        consecutiveResendFailures = 0
        stateLock.unlock()

        persist(nil)
        releaseKeepAlive()

        if wasActive {
            LogManager.shared.addInfoLog("Released simulated location hold")
        }
    }

    // MARK: - Resend loop

    private func startTimer() {
        // Built and installed under the lock so a losing racer never creates a
        // source it has to throw away — a timer source starts suspended, and
        // deallocating a suspended source traps.
        stateLock.lock()
        guard timer == nil else {
            stateLock.unlock()
            return
        }

        let source = DispatchSource.makeTimerSource(queue: timerQueue)
        source.schedule(
            deadline: .now() + Self.resendInterval,
            repeating: Self.resendInterval,
            leeway: .milliseconds(500)
        )
        source.setEventHandler { [weak self] in
            self?.resend()
        }
        timer = source
        stateLock.unlock()

        source.resume()
    }

    private func resend() {
        guard let target = activeCoordinate else { return }

        // `simulate_location` reuses its cached connection and rebuilds it if the
        // set fails, so a dropped tunnel (e.g. a Wi-Fi<->cellular handoff) heals
        // on the next tick. A failure here is expected and transient; the next
        // resend retries.
        LocationSimulationCommandQueue.shared.async { [weak self] in
            let code = simulate_location(
                DeviceConnectionContext.targetIPAddress,
                target.latitude,
                target.longitude,
                PairingFileStore.prepareURL().path
            )
            self?.noteResendResult(code)
        }
    }

    /// Surfaces hold health in the log without spamming it: the first failure,
    /// the recovery, and a heartbeat roughly every five minutes while failing.
    private func noteResendResult(_ code: Int32) {
        stateLock.lock()
        let previousFailures = consecutiveResendFailures
        consecutiveResendFailures = code == 0 ? 0 : previousFailures + 1
        let failures = consecutiveResendFailures
        stateLock.unlock()

        if code == 0 {
            if previousFailures > 0 {
                LogManager.shared.addInfoLog(
                    "Simulated location resend recovered after \(previousFailures) failed attempt(s)"
                )
            }
        } else if failures == 1 {
            LogManager.shared.addWarningLog(
                "Simulated location resend failed (error \(code)); retrying every \(Int(Self.resendInterval))s"
            )
        } else if failures % 75 == 0 {
            LogManager.shared.addWarningLog(
                "Simulated location resend still failing after \(failures) attempts (error \(code)) — the held location is NOT being applied"
            )
        }
    }

    // MARK: - Keep-alive

    private func acquireKeepAlive() {
        stateLock.lock()
        let alreadyHolding = isHolding
        isHolding = true
        stateLock.unlock()

        guard !alreadyHolding else { return }

        runOnMain {
            // Forced holds: an active simulation must keep the app running even
            // if the user's keep-alive toggles are off, otherwise iOS suspends us
            // and the resends stop.
            BackgroundAudioManager.shared.requestStart(force: true)
            BackgroundLocationManager.shared.requestStart(force: true)
            self.beginBackgroundTask()
        }
    }

    private func releaseKeepAlive() {
        stateLock.lock()
        let wasHolding = isHolding
        isHolding = false
        stateLock.unlock()

        guard wasHolding else { return }

        runOnMain {
            BackgroundAudioManager.shared.requestStop(force: true)
            BackgroundLocationManager.shared.requestStop(force: true)
            self.endBackgroundTask()
        }
    }

    // MARK: - Background task (main-thread only)

    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "StikDebugLocationSimulation") { [weak self] in
            guard let self else { return }
            // Silent audio is what actually sustains background execution, so do
            // not tear the hold down when this assertion expires — take a fresh
            // one and keep resending.
            if self.isActive {
                LogManager.shared.addInfoLog("Location simulation background window renewed")
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
            DispatchQueue.main.async(execute: work)
        }
    }
}
