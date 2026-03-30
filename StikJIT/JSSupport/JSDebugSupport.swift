//
//  JSDebugSupport.swift
//  StikDebug
//
//  Created by Stephen on 2026/3/30.
//

import Foundation
import JavaScriptCore
import idevice

private func jsException(_ message: String, in context: JSContext?) {
    guard let context else { return }
    context.exception = JSValue(object: message, in: context)
}

private func describeIdeviceError(_ ffiError: UnsafeMutablePointer<IdeviceFfiError>) -> String {
    if let message = ffiError.pointee.message {
        return "error code \(ffiError.pointee.code), msg \(String(cString: message))"
    }
    return "error code \(ffiError.pointee.code)"
}

func handleJSContextSendDebugCommand(_ context: JSContext?, _ commandStr: String, _ debugProxy: OpaquePointer?) -> String? {
    guard let debugProxy else {
        jsException("debug proxy is unavailable", in: context)
        return nil
    }

    guard let command = debugserver_command_new(commandStr, nil, 0) else {
        jsException("failed to allocate debugserver command", in: context)
        return nil
    }

    var response: UnsafeMutablePointer<CChar>?
    let ffiError = debug_proxy_send_command(debugProxy, command, &response)
    debugserver_command_free(command)

    if let ffiError {
        jsException(describeIdeviceError(ffiError), in: context)
        idevice_error_free(ffiError)
        if let response {
            idevice_string_free(response)
        }
        return nil
    }

    defer {
        if let response {
            idevice_string_free(response)
        }
    }

    guard let response else { return nil }
    return String(cString: response)
}

private func hexCharacter(for value: UInt8) -> UInt8 {
    if value < 10 {
        return value + Character("0").asciiValue!
    }
    return value + 87
}

private func fillAddress(into buffer: inout [UInt8], at index: Int, address: UInt64) {
    let masks: [UInt64] = [
        0xf00000000,
        0x0f0000000,
        0x00f000000,
        0x000f00000,
        0x0000f0000,
        0x00000f000,
        0x000000f00,
        0x0000000f0,
        0x00000000f,
    ]

    for (offset, mask) in masks.enumerated() {
        let shift = UInt64((masks.count - 1 - offset) * 4)
        let nibble = UInt8((address & mask) >> shift)
        buffer[index + offset] = hexCharacter(for: nibble)
    }
}

private func writeChecksum(into buffer: inout [UInt8], at startIndex: Int) {
    var checksum: UInt8 = 0
    var index = startIndex
    while buffer[index] != Character("#").asciiValue! {
        checksum &+= buffer[index]
        index += 1
    }

    buffer[index + 1] = hexCharacter(for: (checksum & 0xf0) >> 4)
    buffer[index + 2] = hexCharacter(for: checksum & 0x0f)
}

private func makeBulkWriteCommands(startAddress: UInt64, pageSize: UInt64) -> [UInt8] {
    let commandCount = Int(pageSize >> 14)
    var buffer = [UInt8](repeating: 0, count: commandCount * 19)

    var currentAddress = startAddress
    for commandIndex in 0..<commandCount {
        let start = commandIndex * 19
        buffer[start + 0] = Character("$").asciiValue!
        buffer[start + 1] = Character("M").asciiValue!
        fillAddress(into: &buffer, at: start + 2, address: currentAddress)
        buffer[start + 11] = Character(",").asciiValue!
        buffer[start + 12] = Character("1").asciiValue!
        buffer[start + 13] = Character(":").asciiValue!
        buffer[start + 14] = Character("6").asciiValue!
        buffer[start + 15] = Character("9").asciiValue!
        buffer[start + 16] = Character("#").asciiValue!
        writeChecksum(into: &buffer, at: start + 1)
        currentAddress += 16_384
    }

    return buffer
}

func handleJITPageWrite(_ context: JSContext?, _ startAddr: UInt64, _ jitPagesSize: UInt64, _ debugProxy: OpaquePointer?) -> String? {
    guard let debugProxy else {
        jsException("debug proxy is unavailable", in: context)
        return nil
    }

    let commandBuffer = makeBulkWriteCommands(startAddress: startAddr, pageSize: jitPagesSize)
    let commandCount = Int(jitPagesSize >> 14)
    let commandsPerBatch = 128

    for batchStart in stride(from: 0, to: commandCount, by: commandsPerBatch) {
        let commandsToSend = min(commandsPerBatch, commandCount - batchStart)
        let byteOffset = batchStart * 19
        let byteCount = commandsToSend * 19

        let ffiError = commandBuffer.withUnsafeBytes { rawBuffer -> UnsafeMutablePointer<IdeviceFfiError>? in
            let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress!
            return debug_proxy_send_raw(debugProxy, baseAddress.advanced(by: byteOffset), UInt(byteCount))
        }

        if let ffiError {
            jsException(describeIdeviceError(ffiError), in: context)
            idevice_error_free(ffiError)
            return nil
        }

        for _ in 0..<commandsToSend {
            var response: UnsafeMutablePointer<CChar>?
            let ffiError = debug_proxy_read_response(debugProxy, &response)
            if let response {
                idevice_string_free(response)
            }
            if let ffiError {
                jsException(describeIdeviceError(ffiError), in: context)
                idevice_error_free(ffiError)
                return nil
            }
        }
    }

    return "OK"
}
