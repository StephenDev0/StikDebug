//
//  Extensions.swift
//  StikDebug
//
//  Created by s s on 2025/7/9.
//

extension FileManager {
    func filePath(atPath path: String, withLength length: Int) -> String? {
        guard let file = try? contentsOfDirectory(atPath: path).filter({ $0.count == length }).first else { return nil }
        return "\(path)/\(file)"
    }
}

public extension ProcessInfo {
    var hasTXM: Bool {
        { if let boot = FileManager.default.filePath(atPath: "/System/Volumes/Preboot", withLength: 36), let file = FileManager.default.filePath(atPath: "\(boot)/boot", withLength: 96) { return access("\(file)/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0 } else { return (FileManager.default.filePath(atPath: "/private/preboot", withLength: 96).map { access("\($0)/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0 }) ?? false } }()
    }
}
