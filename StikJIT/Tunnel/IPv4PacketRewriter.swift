//
//  IPv4PacketRewriter.swift
//  StikDebug
//

enum IPv4PacketRewriter {
    static func swapEndpoints(in packet: inout [UInt8]) {
        guard packet.count >= 20, packet[0] >> 4 == 4 else {
            return
        }

        for offset in 0..<4 {
            packet.swapAt(12 + offset, 16 + offset)
        }
    }
}
