//
//  ProcessInfo+TXM.swift
//  StikDebug
//

import Foundation

public extension ProcessInfo {
    var hasTXM: Bool {
        if isTXMOverridden {
            return true
        }

        return ProcessInfo.hasTXMSupport(
            operatingSystemVersion: operatingSystemVersion,
            localTXMDetector: ProcessInfo.detectLocalTXM
        )
    }

    var isTXMOverridden: Bool {
        UserDefaults.standard.bool(forKey: UserDefaults.Keys.txmOverride)
    }

    static func hasTXMSupport(
        operatingSystemVersion: OperatingSystemVersion,
        localTXMDetector: () -> Bool
    ) -> Bool {
        guard operatingSystemVersion.majorVersion >= 26 else {
            return false
        }
        return localTXMDetector()
    }

    private static func detectLocalTXM() -> Bool {
        if let boot = FileManager.default.filePath(atPath: "/System/Volumes/Preboot", withLength: 36),
           let file = FileManager.default.filePath(atPath: "\(boot)/boot", withLength: 96) {
            return access("\(file)/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0
        }

        return FileManager.default.filePath(atPath: "/private/preboot", withLength: 96).map {
            access("\($0)/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0
        } ?? false
    }
}
