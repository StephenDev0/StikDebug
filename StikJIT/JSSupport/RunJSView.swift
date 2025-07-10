//
//  RunJSView.swift
//  StikJIT
//
//  Created by s s on 2025/4/24.
//

import SwiftUI
import JavaScriptCore

class RunJSViewModel: ObservableObject {
    var context: JSContext?
    @Published var logs: [String] = []
    @Published var scriptName: String = "Script"
    @Published var executionInterrupted = false
    var pid: Int
    var debugProxy: OpaquePointer?
    var semaphore: dispatch_semaphore_t?
    
    init(pid: Int, debugProxy: OpaquePointer?, semaphore: dispatch_semaphore_t?) {
        self.pid = pid
        self.debugProxy = debugProxy
        self.semaphore = semaphore
    }
    
    func runScript(path: URL) throws {
        let scriptContent = try String(contentsOf: path, encoding: .utf8)
        scriptName = path.lastPathComponent
        
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
        
        let hasTXMFunction: @convention(block) () -> Bool = {
            return ProcessInfo.processInfo.hasTXM
        }
        
        context = JSContext()
        context?.setObject(hasTXMFunction, forKeyedSubscript: "hasTXM" as NSString)
        context?.setObject(getPidFunction, forKeyedSubscript: "get_pid" as NSString)
        context?.setObject(sendCommandFunction, forKeyedSubscript: "send_command" as NSString)
        context?.setObject(prepareMemoryRegionFunction, forKeyedSubscript: "prepare_memory_region" as NSString)
        context?.setObject(logFunction, forKeyedSubscript: "log" as NSString)
        
        context?.evaluateScript(scriptContent)
        if let semaphore {
            semaphore.signal()
        }
        PiPController.shared.stopPiP()
        
        DispatchQueue.main.async {
            if let exception = self.context?.exception {
                self.logs.append(exception.debugDescription)
            }
            
            self.logs.append("Script Execution Completed, \nYou are safe to close the PIP Window.")
        }
    }
}

struct RunJSViewPiP: View {
    @Binding var model: RunJSViewModel?
    @State var logs: [String] = []
    let timer = Timer.publish(every: 0.034, on: .main, in: .common).autoconnect()
    

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(logs.suffix(6).indices, id: \.self) { index in
                Text(logs.suffix(6)[index])
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .onReceive(timer) { _ in
            self.logs = model?.logs ?? []
        }
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
            .onChange(of: model.logs.count) { newCount in
                guard newCount > 0 else { return }
                withAnimation {
                    proxy.scrollTo(newCount - 1, anchor: .bottom)
                }
            }
        }
    }
}
