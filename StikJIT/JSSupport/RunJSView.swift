//
//  RunJSView.swift
//  StikJIT
//
//  Created by s s on 2025/4/24.
//

import SwiftUI
import JavaScriptCore


class RunJSViewModel : ObservableObject {
    var context: JSContext?
    @Published var logs: [String] = []
    @Published var scriptName : String = "Script"
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
                self.context?.exception = JSValue(object: "command should not be nil", in: self.context!)
                return nil
            }
            
            return handleJSContextSendDebugCommand(self.context, commandStr, self.debugProxy) ?? ""
        }
        
        let logFunction: @convention(block) (String) -> Void = { logStr in
            DispatchQueue.main.async {
                self.logs.append(logStr)
            }
        }
        
        context = JSContext()
        context?.setObject(getPidFunction, forKeyedSubscript: "get_pid" as NSString)
        context?.setObject(sendCommandFunction, forKeyedSubscript: "send_command" as NSString)
        context?.setObject(logFunction, forKeyedSubscript: "log" as NSString)
        
        context?.evaluateScript(scriptContent)
        if let semaphore {
            semaphore.signal()
        }
        DispatchQueue.main.async {
            if let exception = self.context?.exception {
                self.logs.append(exception.debugDescription)
            }
            self.logs.append("Script Execution Completed.")
        }
    }
    
}

struct RunJSView : View {
    @ObservedObject var model : RunJSViewModel
    @State var webViewShow = false
    
    var body: some View {
        List {
            ForEach(model.logs, id: \.self) { logStr in
                Text(logStr)
            }
        }
        .navigationTitle("Running \(model.scriptName)")
    }
    
}
