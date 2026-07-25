//
//  NetworkPathMonitor.swift
//  StikDebug
//

import Foundation
import Network

/// Observes the device's network path so the app never *assumes* Wi-Fi.
///
/// StikDebug reaches the device's own services through LocalDevVPN's tunnel,
/// which works over Wi-Fi *or* cellular. This monitor reports what path is
/// actually available (including cellular and VPN) and broadcasts changes so the
/// tunnel can reconnect after a Wi-Fi↔cellular handoff instead of silently
/// staying dropped.
final class NetworkPathMonitor {
    static let shared = NetworkPathMonitor()

    struct Status: CustomStringConvertible {
        var isReachable: Bool
        var isExpensive: Bool
        var usesVPN: Bool
        var interface: NWInterface.InterfaceType?

        var interfaceName: String {
            switch interface {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .wiredEthernet: return "Ethernet"
            case .loopback: return "Loopback"
            case .other: return "Other"
            case .none: return "None"
            @unknown default: return "Unknown"
            }
        }

        var description: String {
            var parts = [isReachable ? "reachable" : "unreachable", interfaceName]
            if usesVPN { parts.append("VPN") }
            if isExpensive { parts.append("expensive") }
            return parts.joined(separator: ", ")
        }
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.stik.networkpath")
    private let stateLock = NSLock()
    private var started = false
    private var current = Status(isReachable: false, isExpensive: false, usesVPN: false, interface: nil)
    private var lastSignature: String?

    private init() {}

    var status: Status {
        stateLock.lock()
        defer { stateLock.unlock() }
        return current
    }

    func start() {
        stateLock.lock()
        guard !started else {
            stateLock.unlock()
            return
        }
        started = true
        stateLock.unlock()

        monitor.pathUpdateHandler = { [weak self] path in
            self?.handle(path)
        }
        monitor.start(queue: queue)
    }

    private func handle(_ path: NWPath) {
        // A utun (VPN) interface reports as `.other`; treat its presence as an
        // active VPN. The primary usable interface is the first one actually in use.
        let usesVPN = path.availableInterfaces.contains { $0.type == .other }
        let interface = path.availableInterfaces.first(where: { path.usesInterfaceType($0.type) })?.type
            ?? path.availableInterfaces.first?.type

        let status = Status(
            isReachable: path.status == .satisfied,
            isExpensive: path.isExpensive,
            usesVPN: usesVPN,
            interface: interface
        )

        let signature = "\(status.isReachable)|\(status.interfaceName)|\(status.usesVPN)"

        stateLock.lock()
        current = status
        let changed = signature != lastSignature
        lastSignature = signature
        stateLock.unlock()

        guard changed else { return }
        LogManager.shared.addInfoLog("Network path: \(status.description)")
        NotificationCenter.default.post(name: .networkPathDidChange, object: nil)
    }
}
