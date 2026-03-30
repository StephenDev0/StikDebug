//
//  RunJSView.swift
//  StikJIT
//
//  Created by s s on 2025/4/24.
//

import SwiftUI
import JavaScriptCore
import idevice

typealias RemoteServerHandle = OpaquePointer
typealias ScreenshotClientHandle = OpaquePointer

final class RunJSViewModel: ObservableObject, @unchecked Sendable {
    var context: JSContext?
    @Published var logs: [String] = []
    @Published var scriptName: String = "Script"
    @Published var executionInterrupted = false
    var pid: Int
    var debugProxy: OpaquePointer?
    var remoteServer: OpaquePointer?
    var semaphore: DispatchSemaphore?
    
    init(pid: Int, debugProxy: OpaquePointer?, remoteServer: OpaquePointer?, semaphore: DispatchSemaphore?) {
        self.pid = pid
        self.debugProxy = debugProxy
        self.remoteServer = remoteServer
        self.semaphore = semaphore
    }
    
    func runScript(path: URL, scriptName: String? = nil) throws {
        try runScript(data: Data(contentsOf: path), name: scriptName)
    }
    
    func runScript(data: Data, name: String? = nil) throws {
        let scriptContent = String(data: data, encoding: .utf8)
        scriptName = name ?? "Script"
        
        let getPidFunction: @convention(block) () -> Int = {
            return self.pid
        }
        
        let sendCommandFunction: @convention(block) (String?) -> String? = { commandStr in
            guard let commandStr else {
                self.context?.exception = JSValue(object: "Command should not be nil.", in: self.context!)
                return ""
            }
            if self.executionInterrupted {
                self.context?.exception = JSValue(object: "Script execution is interrupted by StikDebug.", in: self.context!)
                return ""
            }
            
            return handleJSContextSendDebugCommand(self.context, commandStr, self.debugProxy) ?? ""
        }
        
        let logFunction: @convention(block) (String) -> Void = { logStr in
            DispatchQueue.main.async {
                self.logs.append(logStr)
            }
        }
        
        let prepareMemoryRegionFunction: @convention(block) (UInt64, UInt64) -> String = { startAddr, regionSize in
            return handleJITPageWrite(self.context, startAddr, regionSize, self.debugProxy) ?? ""
        }
        
        let takeScreenshotFunction: @convention(block) (String?) -> String? = { fileName in
            return self.captureScreenshot(named: fileName)
        }
        
        let hasTXMFunction: @convention(block) () -> Bool = {
            return ProcessInfo.processInfo.hasTXM
        }
        
        context = JSContext()
        context?.setObject(hasTXMFunction, forKeyedSubscript: "hasTXM" as NSString)
        context?.setObject(getPidFunction, forKeyedSubscript: "get_pid" as NSString)
        context?.setObject(sendCommandFunction, forKeyedSubscript: "send_command" as NSString)
        context?.setObject(prepareMemoryRegionFunction, forKeyedSubscript: "prepare_memory_region" as NSString)
        context?.setObject(takeScreenshotFunction, forKeyedSubscript: "take_screenshot" as NSString)
        context?.setObject(logFunction, forKeyedSubscript: "log" as NSString)
        
        context?.evaluateScript(scriptContent)
        if let semaphore {
            semaphore.signal()
        }

        DispatchQueue.main.async {
            if let exception = self.context?.exception {
                self.logs.append(exception.debugDescription)
            }
            self.logs.append("Script Execution Completed")
            self.logs.append("You are safe to close this window.")
        }
    }
    
    private func captureScreenshot(named preferredName: String?) -> String {
        if executionInterrupted {
            raiseException("Script execution is interrupted by StikDebug.")
            return ""
        }
        guard let remoteServer else {
            raiseException("Screenshot capture is unavailable in the current session.")
            return ""
        }
        
        var screenshotClient: ScreenshotClientHandle?
        let creationError = screenshot_client_new(remoteServer, &screenshotClient)
        if let creationError {
            let message = describeIdeviceError(creationError)
            idevice_error_free(creationError)
            raiseException("Failed to create screenshot client: \(message)")
            return ""
        }
        guard let screenshotClient else {
            raiseException("Failed to allocate screenshot client.")
            return ""
        }
        defer { screenshot_client_free(screenshotClient) }
        
        var buffer: UnsafeMutablePointer<UInt8>?
        var length: UInt = 0
        let captureError = screenshot_client_take_screenshot(screenshotClient, &buffer, &length)
        if let captureError {
            let message = describeIdeviceError(captureError)
            idevice_error_free(captureError)
            raiseException("Failed to take screenshot: \(message)")
            return ""
        }
        guard let buffer else {
            raiseException("Device returned empty screenshot data.")
            return ""
        }
        defer { idevice_data_free(buffer, length) }
        
        let data = Data(bytes: buffer, count: Int(length))
        do {
            let fileURL = try screenshotFileURL(preferredName: preferredName)
            try data.write(to: fileURL, options: .atomic)
            return fileURL.path
        } catch {
            raiseException("Failed to save screenshot: \(error.localizedDescription)")
            return ""
        }
    }
    
    private func screenshotFileURL(preferredName: String?) throws -> URL {
        let directory = URL.documentsDirectory.appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileManager = FileManager.default
        let initialName = sanitizedScreenshotName(from: preferredName)
        var targetURL = directory.appendingPathComponent(initialName)
        guard fileManager.fileExists(atPath: targetURL.path) else {
            return targetURL
        }
        
        let baseName = targetURL.deletingPathExtension().lastPathComponent
        let ext = targetURL.pathExtension.isEmpty ? "png" : targetURL.pathExtension
        var counter = 1
        repeat {
            let candidate = "\(baseName)-\(counter).\(ext)"
            targetURL = directory.appendingPathComponent(candidate)
            counter += 1
        } while fileManager.fileExists(atPath: targetURL.path)
        return targetURL
    }
    
    private func sanitizedScreenshotName(from preferredName: String?) -> String {
        let defaultName = "screenshot-\(Int(Date().timeIntervalSince1970))"
        guard let candidate = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !candidate.isEmpty else {
            return "\(defaultName).png"
        }
        
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        var sanitized = ""
        sanitized.reserveCapacity(candidate.count)
        for scalar in candidate.unicodeScalars {
            if allowed.contains(scalar) {
                sanitized.append(Character(scalar))
            } else {
                sanitized.append("_")
            }
        }
        if sanitized.isEmpty {
            sanitized = defaultName
        }
        if !sanitized.lowercased().hasSuffix(".png") {
            sanitized += ".png"
        }
        return sanitized
    }
    
    private func describeIdeviceError(_ error: UnsafeMutablePointer<IdeviceFfiError>) -> String {
        if let messagePointer = error.pointee.message {
            return "[\(error.pointee.code)] \(String(cString: messagePointer))"
        }
        return "[\(error.pointee.code)] Unknown error"
    }
    
    private func raiseException(_ message: String) {
        guard let context else { return }
        context.exception = JSValue(object: message, in: context)
    }
}

struct RunJSView: View {
    @ObservedObject var model: RunJSViewModel

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(model.logs.enumerated()), id: \.offset) { index, logStr in
                    Text(logStr)
                        .id(index)
                }
            }
            .navigationTitle("Running \(model.scriptName)")
            .onChange(of: model.logs.count) { _, newCount in
                guard newCount > 0 else { return }
                withAnimation {
                    proxy.scrollTo(newCount - 1, anchor: .bottom)
                }
            }
        }
    }
}
