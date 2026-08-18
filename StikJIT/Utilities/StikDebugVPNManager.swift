//
//  StikDebugVPNManager.swift
//  StikDebug
//

import Combine
import Foundation
import NetworkExtension

final class StikDebugVPNManager: ObservableObject {
    static let shared = StikDebugVPNManager()
    static let providerBundleIdentifier = "com.stik.stikdebug.tunnel"

    @Published private(set) var currentStatus: StikDebugVPNStatus = .disconnected

    private let stateLock = NSLock()
    private var manager: NETunnelProviderManager?
    private var startingWaiter: DispatchSemaphore?
    private var lastEnsureError: Error?

    private init() {}

    static func makeProviderConfiguration(
        for configuration: StikDebugTunnelConfiguration
    ) -> [String: String] {
        configuration.providerConfiguration
    }

    func start() throws {
        try ensureReady()
    }

    func ensureReady() throws {
        stateLock.lock()
        if let startingWaiter {
            stateLock.unlock()
            startingWaiter.wait()
            stateLock.lock()
            let error = lastEnsureError
            stateLock.unlock()
            if let error { throw error }
            return
        }

        let waiter = DispatchSemaphore(value: 0)
        startingWaiter = waiter
        lastEnsureError = nil
        stateLock.unlock()

        var ensureError: Error?
        defer {
            stateLock.lock()
            lastEnsureError = ensureError
            startingWaiter = nil
            stateLock.unlock()
            waiter.signal()
        }

        do {
            try ensureReadyOnce()
        } catch {
            ensureError = error
            throw error
        }
    }

    func stop() {
        stateLock.lock()
        let activeManager = manager
        stateLock.unlock()

        activeManager?.connection.stopVPNTunnel()
        publish(.disconnected)
    }

    func isTunnelReady() -> Bool {
        stateLock.lock()
        let status = manager?.connection.status
        stateLock.unlock()
        return status == .connected
    }

    private func ensureReadyOnce() throws {
        let configured = StikDebugTunnelConfiguration(
            interfaceIP: StikDebugTunnelConfiguration.default.interfaceIP,
            peerIP: DeviceConnectionContext.targetIPAddress
        )
        let managers = try loadManagers()

        if managers.contains(where: { manager in
            isActive(manager) && !isOwned(manager)
        }) {
            throw StikDebugVPNError.competingVPN
        }

        let selectedManager: NETunnelProviderManager
        if let existing = managers.first(where: isOwned) {
            selectedManager = existing
            try reload(existing)
        } else {
            selectedManager = NETunnelProviderManager()
        }

        let status = selectedManager.connection.status
        publish(StikDebugVPNStatus(neStatus: status))
        if status == .connected {
            stateLock.lock()
            manager = selectedManager
            stateLock.unlock()
            return
        }

        configure(selectedManager, with: configured)
        selectedManager.isEnabled = true
        try save(selectedManager)
        try reload(selectedManager)

        stateLock.lock()
        manager = selectedManager
        stateLock.unlock()

        let options = configured.providerConfiguration.reduce(into: [String: NSObject]()) { result, item in
            result[item.key] = item.value as NSString
        }

        publish(.connecting)
        do {
            try selectedManager.connection.startVPNTunnel(options: options)
        } catch {
            throw StikDebugVPNError.startFailed(error.localizedDescription)
        }

        try waitForConnection(selectedManager)
    }

    private func configure(
        _ manager: NETunnelProviderManager,
        with configuration: StikDebugTunnelConfiguration
    ) {
        let protocolConfiguration =
            (manager.protocolConfiguration as? NETunnelProviderProtocol)
            ?? NETunnelProviderProtocol()

        protocolConfiguration.providerBundleIdentifier = Self.providerBundleIdentifier
        protocolConfiguration.serverAddress = "StikDebug Local Tunnel"
        protocolConfiguration.providerConfiguration = configuration.providerConfiguration.reduce(into: [String: Any]()) {
            $0[$1.key] = $1.value
        }
        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = "StikDebug Local Tunnel"

        let onDemandRule = NEOnDemandRuleEvaluateConnection()
        onDemandRule.interfaceTypeMatch = .any
        onDemandRule.connectionRules = [
            NEEvaluateConnectionRule(
                matchDomains: [configuration.peerIP],
                andAction: .connectIfNeeded
            )
        ]
        manager.onDemandRules = [onDemandRule]
        manager.isOnDemandEnabled = true
    }

    private func isOwned(_ manager: NETunnelProviderManager) -> Bool {
        guard let configuration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return false
        }
        return configuration.providerBundleIdentifier == Self.providerBundleIdentifier
    }

    private func isActive(_ manager: NETunnelProviderManager) -> Bool {
        switch manager.connection.status {
        case .connected, .connecting, .reasserting:
            return true
        default:
            return false
        }
    }

    private func waitForConnection(_ manager: NETunnelProviderManager) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let connection = manager.connection
        let observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: connection,
            queue: nil
        ) { [weak self] _ in
            let status = connection.status
            self?.publish(StikDebugVPNStatus(neStatus: status))
            if status == .connected || status == .disconnected || status == .invalid {
                semaphore.signal()
            }
        }

        if connection.status == .connected {
            NotificationCenter.default.removeObserver(observer)
            publish(.connected)
            return
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10) {
            semaphore.signal()
        }
        semaphore.wait()
        NotificationCenter.default.removeObserver(observer)

        let finalStatus = connection.status
        publish(StikDebugVPNStatus(neStatus: finalStatus))
        guard finalStatus == .connected else {
            if finalStatus == .disconnected || finalStatus == .invalid {
                throw StikDebugVPNError.disconnected
            }
            throw StikDebugVPNError.timeout
        }
    }

    private func loadManagers() throws -> [NETunnelProviderManager] {
        let semaphore = DispatchSemaphore(value: 0)
        var loadedManagers: [NETunnelProviderManager] = []
        var loadError: Error?

        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            loadedManagers = managers ?? []
            loadError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let loadError {
            throw StikDebugVPNError.profileLoadFailed(loadError.localizedDescription)
        }
        return loadedManagers
    }

    private func reload(_ manager: NETunnelProviderManager) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var reloadError: Error?
        manager.loadFromPreferences { error in
            reloadError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let reloadError {
            throw StikDebugVPNError.profileLoadFailed(reloadError.localizedDescription)
        }
    }

    private func save(_ manager: NETunnelProviderManager) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var saveError: Error?
        manager.saveToPreferences { error in
            saveError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let saveError {
            throw StikDebugVPNError.profileSaveFailed(saveError.localizedDescription)
        }
    }

    private func publish(_ status: StikDebugVPNStatus) {
        if Thread.isMainThread {
            currentStatus = status
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.currentStatus = status
            }
        }
    }
}
