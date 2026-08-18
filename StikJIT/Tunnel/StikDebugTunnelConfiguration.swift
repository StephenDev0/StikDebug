//
//  StikDebugTunnelConfiguration.swift
//  StikDebug
//

struct StikDebugTunnelConfiguration: Equatable {
    static let interfaceIPKey = "interfaceIP"
    static let peerIPKey = "peerIP"

    static let `default` = StikDebugTunnelConfiguration(
        interfaceIP: "10.7.0.0",
        peerIP: "10.7.0.1"
    )

    let interfaceIP: String
    let peerIP: String
    let peerPrefixLength: Int

    init(interfaceIP: String, peerIP: String, peerPrefixLength: Int = 32) {
        self.interfaceIP = interfaceIP
        self.peerIP = peerIP
        self.peerPrefixLength = peerPrefixLength
    }

    var providerConfiguration: [String: String] {
        [
            Self.interfaceIPKey: interfaceIP,
            Self.peerIPKey: peerIP,
        ]
    }
}
