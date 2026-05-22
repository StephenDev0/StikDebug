//
//  StikDebugTests.swift
//  StikDebugTests
//
//  Created by Stephen on 3/26/25.
//

import Foundation
import Testing
@testable import StikDebug

struct StikDebugTests {

    @Test func txmDetectionIgnoresFirmwareFileBeforeIOS26() async throws {
        let isSupported = ProcessInfo.hasTXMSupport(
            operatingSystemVersion: OperatingSystemVersion(majorVersion: 18, minorVersion: 7, patchVersion: 2),
            localTXMDetector: { true }
        )

        #expect(isSupported == false)
    }

    @Test func txmDetectionRequiresLocalTXMOnIOS26() async throws {
        let iOS26 = OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)

        #expect(ProcessInfo.hasTXMSupport(operatingSystemVersion: iOS26, localTXMDetector: { false }) == false)
        #expect(ProcessInfo.hasTXMSupport(operatingSystemVersion: iOS26, localTXMDetector: { true }) == true)
    }

}
