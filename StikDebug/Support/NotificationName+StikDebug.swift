//
//  NotificationName+StikDebug.swift
//  StikDebug
//

import Foundation

extension Notification.Name {
    static let pairingFileImported = Notification.Name("PairingFileImported")
    static let intentJSScriptReady = Notification.Name("intentJSScriptReady")
    /// Posted when the reachable network path changes (interface type, VPN
    /// presence, or reachability), so the tunnel can revalidate/reconnect.
    static let networkPathDidChange = Notification.Name("NetworkPathDidChange")
}
