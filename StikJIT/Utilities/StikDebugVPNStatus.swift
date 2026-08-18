//
//  StikDebugVPNStatus.swift
//  StikDebug
//

import NetworkExtension

enum StikDebugVPNStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failed

    init(neStatus: NEVPNStatus) {
        switch neStatus {
        case .invalid, .disconnected:
            self = .disconnected
        case .connecting, .reasserting:
            self = .connecting
        case .connected:
            self = .connected
        case .disconnecting:
            self = .disconnecting
        @unknown default:
            self = .failed
        }
    }

    var isConnected: Bool {
        self == .connected
    }
}

enum StikDebugVPNError: LocalizedError, Equatable {
    case profileLoadFailed(String)
    case profileSaveFailed(String)
    case permissionDenied(String)
    case mustRunOffMainThread
    case timeout
    case startFailed(String)
    case disconnected

    var errorDescription: String? {
        switch self {
        case .profileLoadFailed(let message):
            return "Unable to load the embedded VPN profile: \(message)"
        case .profileSaveFailed(let message):
            return "Unable to save the embedded VPN profile: \(message)"
        case .permissionDenied(let message):
            return "The embedded VPN permission was denied: \(message)"
        case .mustRunOffMainThread:
            return "The embedded VPN must be started from a background queue."
        case .timeout:
            return "The embedded VPN did not become connected before the timeout."
        case .startFailed(let message):
            return "The embedded VPN could not start: \(message)"
        case .disconnected:
            return "The embedded VPN disconnected before the device tunnel was ready."
        }
    }
}
