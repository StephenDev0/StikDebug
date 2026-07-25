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

    private let stateLock = NSLock()
    private let timerQueue = DispatchQueue(label: "com.stik.location-keepalive")

    private var coordinate: CLLocationCoordinate2D?
    private var timer: DispatchSourceTimer?
    private var isHolding = false

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
        stateLock.unlock()

        acquireKeepAlive()
        startTimer()

        if isFirstHold {
            LogManager.shared.addInfoLog("Holding simulated location (resending every \(Int(Self.resendInterval))s)")
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
        stateLock.unlock()

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
        LocationSimulationCommandQueue.shared.async {
            _ = simulate_location(
                DeviceConnectionContext.targetIPAddress,
                target.latitude,
                target.longitude,
                PairingFileStore.prepareURL().path
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
