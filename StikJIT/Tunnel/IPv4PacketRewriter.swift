//
//  IPv4PacketRewriter.swift
//  StikDebug
//

enum IPv4PacketRewriter {
    static func isIPv4Packet(_ packet: [UInt8]) -> Bool {
        packet.count >= 20 && packet[0] >> 4 == 4
    }

    static func swapEndpoints(in packet: inout [UInt8]) {
        guard isIPv4Packet(packet) else {
            return
        }

        for offset in 0..<4 {
            packet.swapAt(12 + offset, 16 + offset)
        }
    }
}
