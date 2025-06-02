//
//  PacketTunnelProvider.swift
//  TunnelProv
//
//  Created by Stossy11 on 28/03/2025.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    var tunnelDeviceIp: String = "10.8.0.0"
    var tunnelFakeIp: String = "10.8.0.1"
    var tunnelSubnetMask: String = "255.255.255.0"
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        if let deviceIp = options?["TunnelDeviceIP"] as? String {
            tunnelDeviceIp = deviceIp
        }
        if let fakeIp = options?["TunnelFakeIP"] as? String {
            tunnelFakeIp = fakeIp
        }
        
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelDeviceIp)
        let ipv4 = NEIPv4Settings(addresses: [tunnelDeviceIp], subnetMasks: [tunnelSubnetMask])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: tunnelDeviceIp, subnetMask: tunnelSubnetMask)]
        ipv4.excludedRoutes = [.default()]
        settings.ipv4Settings = ipv4
        setTunnelNetworkSettings(settings) { error in
            if error == nil {
                self.readPackets()
            }
            completionHandler(error)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    private func readPackets() {
        packetFlow.readPackets { packets, protocols in
            var output: [Data] = []
            for (i, packet) in packets.enumerated() {
                var modifiedPacket = packet
                if protocols[i].int32Value == AF_INET {
                    modifiedPacket = self.packetReplaceIp(packet, self.tunnelDeviceIp, self.tunnelFakeIp, self.tunnelFakeIp, self.tunnelDeviceIp)
                }

                if modifiedPacket.count >= 20 {
                    var mutableBytes = [UInt8](modifiedPacket)
                    
                    // Swap bytes
                    (mutableBytes[12], mutableBytes[16]) = (mutableBytes[16], mutableBytes[12])
                    (mutableBytes[13], mutableBytes[17]) = (mutableBytes[17], mutableBytes[13])
                    (mutableBytes[14], mutableBytes[18]) = (mutableBytes[18], mutableBytes[14])
                    (mutableBytes[15], mutableBytes[19]) = (mutableBytes[19], mutableBytes[15])

                    modifiedPacket = Data(mutableBytes)
                }

                output.append(modifiedPacket)
            }
            self.packetFlow.writePackets(output, withProtocols: protocols)
            self.readPackets()
        }
    }

    
    private func packetReplaceIp(_ data: Data, _ sourceSearch: String, _ sourceReplace: String, _ destSearch: String, _ destReplace: String) -> Data {
        // Check if packet is too small for IPv4 header
        if data.count < 20 {
            return data
        }
        
        // Convert IP strings to Data with network byte order (big-endian)
        func ipToUInt32(_ ipString: String) -> UInt32 {
            let components = ipString.split(separator: ".")
            var result: UInt32 = 0
            
            if components.count == 4,
               let byte1 = UInt32(components[0]),
               let byte2 = UInt32(components[1]),
               let byte3 = UInt32(components[2]),
               let byte4 = UInt32(components[3]) {
                result = (byte1 << 24) | (byte2 << 16) | (byte3 << 8) | byte4
            }
            
            return result
        }
        
        // Convert IP strings to UInt32
        let sourceSearchIP = ipToUInt32(sourceSearch)
        let sourceReplaceIP = ipToUInt32(sourceReplace)
        let destSearchIP = ipToUInt32(destSearch)
        let destReplaceIP = ipToUInt32(destReplace)
        
        // Extract source and destination IPs from packet
        var sourcePacketIP: UInt32 = 0
        var destPacketIP: UInt32 = 0
        
        (data as NSData).getBytes(&sourcePacketIP, range: NSRange(location: 12, length: 4))
        (data as NSData).getBytes(&destPacketIP, range: NSRange(location: 16, length: 4))
        
        if sourceSearchIP != sourcePacketIP && destSearchIP != destPacketIP {
            return data
        }
        
        let mutableData = NSMutableData(data: data)
        
        if sourceSearchIP == sourcePacketIP {
            var sourceIP = sourceReplaceIP
            mutableData.replaceBytes(in: NSRange(location: 12, length: 4), withBytes: &sourceIP)
        }
        
        if destSearchIP == destPacketIP {
            var destIP = destReplaceIP
            mutableData.replaceBytes(in: NSRange(location: 16, length: 4), withBytes: &destIP)
        }
        
        return mutableData as Data
    }
    
    // Helper function to convert IP string to Data
    private func ipToData(_ ip: String) -> Data {
        let components = ip.split(separator: ".")
        var data = Data(capacity: 4)
        
        for component in components {
            if let byte = UInt8(component) {
                data.append(byte)
            }
        }
        
        return data
    }
}

