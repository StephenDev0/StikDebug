//
//  PacketTunnelProvider.swift
//  StikDebugTunnel
//

import Darwin
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var interfaceIP = StikDebugTunnelConfiguration.default.interfaceIP
    private var peerIP = StikDebugTunnelConfiguration.default.peerIP
    private var packetLoopActive = false

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let providerConfiguration =
            (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration

        if let value = options?[StikDebugTunnelConfiguration.interfaceIPKey] as? String
            ?? providerConfiguration?[StikDebugTunnelConfiguration.interfaceIPKey] as? String {
            interfaceIP = value
        }
        if let value = options?[StikDebugTunnelConfiguration.peerIPKey] as? String
            ?? providerConfiguration?[StikDebugTunnelConfiguration.peerIPKey] as? String {
            peerIP = value
        }

        let ipv4Settings = NEIPv4Settings(
            addresses: [interfaceIP],
            subnetMasks: ["255.255.255.0"]
        )
        ipv4Settings.includedRoutes = [
            NEIPv4Route(
                destinationAddress: peerIP,
                subnetMask: "255.255.255.255"
            )
        ]
        ipv4Settings.excludedRoutes = [.default()]

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: peerIP)
        settings.ipv4Settings = ipv4Settings

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else {
                completionHandler(error)
                return
            }

            if let error {
                completionHandler(error)
                return
            }

            packetLoopActive = true
            readPackets()
            completionHandler(nil)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        packetLoopActive = false
        completionHandler()
    }

    private func readPackets() {
        guard packetLoopActive else { return }

        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self, self.packetLoopActive else { return }

            var rewrittenPackets = packets
            for index in rewrittenPackets.indices {
                guard protocols[index].int32Value == AF_INET else { continue }
                rewrittenPackets[index].withUnsafeMutableBytes { rawBuffer in
                    guard let baseAddress = rawBuffer.baseAddress else { return }
                    var packet = Array(
                        UnsafeRawBufferPointer(
                            start: baseAddress,
                            count: rawBuffer.count
                        )
                    )
                    IPv4PacketRewriter.swapEndpoints(in: &packet)
                    packet.withUnsafeBytes { rewrittenBuffer in
                        rawBuffer.copyBytes(from: rewrittenBuffer)
                    }
                }
            }

            self.packetFlow.writePackets(rewrittenPackets, withProtocols: protocols)
            self.readPackets()
        }
    }
}
