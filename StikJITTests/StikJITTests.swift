//
//  StikJITTests.swift
//  StikJITTests
//
//  Created by Stephen on 3/26/25.
//

import Foundation
import Testing
@testable import StikDebug

struct StikJITTests {

    @Test func transportEndpointUsesRPPairingPort() throws {
        let endpoint = try RPPairingEndpoint(ip: "10.7.0.1")

        #expect(endpoint.port == 49152)
        #expect(endpoint.ip == "10.7.0.1")
    }

    @Test func transportEndpointRejectsMalformedIPv4() {
        #expect(throws: DeviceTransportError.self) {
            try RPPairingEndpoint(ip: "not-an-ip")
        }
    }

    @Test func transportErrorsDoNotReportWiFiAsTheRootCause() {
        let message = DeviceTransportError.vpnUnavailable("permission denied").errorDescription ?? ""

        #expect(!message.localizedCaseInsensitiveContains("wifi"))
        #expect(message.localizedCaseInsensitiveContains("vpn"))
    }

    @Test func vpnStartErrorPreservesUnderlyingMessage() {
        let message = StikDebugVPNError.startFailed("permission denied").errorDescription ?? ""

        #expect(message.localizedCaseInsensitiveContains("permission denied"))
    }

    @Test func vpnStatusMappingRecognizesConnectedAndReasserting() {
        #expect(StikDebugVPNStatus(neStatus: .connected) == .connected)
        #expect(StikDebugVPNStatus(neStatus: .reasserting) == .connecting)
        #expect(StikDebugVPNStatus(neStatus: .disconnected) == .disconnected)
    }

    @Test func vpnManagerConfigurationUsesEmbeddedExtension() {
        let configuration = StikDebugVPNManager.makeProviderConfiguration(
            for: .default
        )

        #expect(configuration[StikDebugTunnelConfiguration.interfaceIPKey] == "10.7.0.0")
        #expect(configuration[StikDebugTunnelConfiguration.peerIPKey] == "10.7.0.1")
        #expect(StikDebugVPNManager.providerBundleIdentifier == "com.stik.stikdebug.tunnel")
    }

    @Test func embeddedTunnelDefaultsMatchLocalDevVPNEndpoint() {
        let configuration = StikDebugTunnelConfiguration.default

        #expect(configuration.interfaceIP == "10.7.0.0")
        #expect(configuration.peerIP == "10.7.0.1")
        #expect(configuration.peerPrefixLength == 32)
        #expect(configuration.providerConfiguration["interfaceIP"] == "10.7.0.0")
        #expect(configuration.providerConfiguration["peerIP"] == "10.7.0.1")
    }

    @Test func ipv4PacketRewriterSwapsPacketEndpoints() {
        var packet = [UInt8](repeating: 0, count: 20)
        packet[0] = 0x45
        packet.replaceSubrange(12..<16, with: [10, 7, 0, 2])
        packet.replaceSubrange(16..<20, with: [10, 7, 0, 1])

        IPv4PacketRewriter.swapEndpoints(in: &packet)

        #expect(Array(packet[12..<16]) == [10, 7, 0, 1])
        #expect(Array(packet[16..<20]) == [10, 7, 0, 2])
    }

    @Test func ipv4PacketRewriterRecognizesOnlyCompleteIPv4Packets() {
        #expect(IPv4PacketRewriter.isIPv4Packet([UInt8(0x45)] + [UInt8](repeating: 0, count: 19)))
        #expect(!IPv4PacketRewriter.isIPv4Packet([UInt8(0x60)] + [UInt8](repeating: 0, count: 19)))
        #expect(!IPv4PacketRewriter.isIPv4Packet([UInt8(0x45)] + [UInt8](repeating: 0, count: 18)))
    }

    @Test func ipv4PacketRewriterLeavesShortPacketsUnchanged() {
        var packet = [UInt8](repeating: 0, count: 19)
        let original = packet

        IPv4PacketRewriter.swapEndpoints(in: &packet)

        #expect(packet == original)
    }

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
