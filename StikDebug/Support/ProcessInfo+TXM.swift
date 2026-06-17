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

        let hardware = hardwareIdentifier()

        if ProcessInfo.isIOS27OrNewer {
            return hardware != "iPad8,11" && hardware != "iPad8,12"
        }

        if ProcessInfo.isIOS26OrNewer {
            return ProcessInfo.hasTXMSupport(
                hardwareIdentifier: hardware
            )
        }

        return false
    }

    var isTXMOverridden: Bool {
        UserDefaults.standard.bool(forKey: UserDefaults.Keys.txmOverride)
    }

    internal static func hasTXMSupport(
        hardwareIdentifier: String
    ) -> Bool {
        let firstTXM = 14.2
        let iPadTXM = 14.5

        guard let ver = ProcessInfo.processInfo.deviceVersion(from: hardwareIdentifier) else {
            return false
        }

        if hardwareIdentifier.hasPrefix("iPad") {
            return ver >= iPadTXM
        }

        return ver >= firstTXM
    }

    func deviceVersion(from identifier: String) -> Double? {
        let iPhonePattern = #"iPhone(\d+),(\d+)"#
        let iPadPattern = #"iPad(\d+),(\d+)"#

        let extractVersion: (_ pattern: String) -> Double? = { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: identifier,
                    range: NSRange(identifier.startIndex..., in: identifier)
                  ),
                  let majorRange = Range(match.range(at: 1), in: identifier),
                  let minorRange = Range(match.range(at: 2), in: identifier),
                  let major = Double(identifier[majorRange]),
                  let minor = Double(identifier[minorRange])
            else {
                return nil
            }

            let divisor = pow(10.0, Double(String(Int(minor)).count))
            return major + (minor / divisor)
        }

        return extractVersion(iPhonePattern) ?? extractVersion(iPadPattern)
    }

    private static var isIOS26OrNewer: Bool {
        if #available(iOS 26.0, *) {
            return true
        }

        return false
    }

    private static var isIOS27OrNewer: Bool {
        if #available(iOS 27.0, *) {
            return true
        }

        return false
    }

    private func hardwareIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
