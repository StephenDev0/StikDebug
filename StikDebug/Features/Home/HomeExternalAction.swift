//
//  HomeExternalAction.swift
//  StikDebug
//

import Foundation
import SwiftUI

struct JITEnableConfiguration {
    var bundleID: String?
    var pid: Int?
    var scriptData: Data?
    var scriptName: String?
}

enum HomeExternalAction: Identifiable {
    case enableJIT(JITEnableConfiguration)
    case killProcess(Int)
    case launchApp(String)

    var id: String {
        switch self {
        case .enableJIT(let configuration):
            return "enable-\(configuration.bundleID ?? "")-\(configuration.pid ?? 0)-\(configuration.scriptName ?? "")"
        case .killProcess(let pid):
            return "kill-\(pid)"
        case .launchApp(let bundleID):
            return "launch-\(bundleID)"
        }
    }

    var title: String {
        switch self {
        case .enableJIT:
            return "Enable JIT?"
        case .killProcess:
            return "Kill Process?"
        case .launchApp:
            return "Launch App?"
        }
    }

    var message: String {
        switch self {
        case .enableJIT(let configuration):
            let scriptText = configuration.scriptData == nil ? "" : " and run a script"
            return "An external link wants to enable JIT\(scriptText) for \(targetDescription(for: configuration))."
        case .killProcess(let pid):
            return "An external link wants to kill process \(pid)."
        case .launchApp(let bundleID):
            return "An external link wants to launch \(bundleID)."
        }
    }

    var confirmationTitle: String {
        switch self {
        case .enableJIT(let configuration):
            return configuration.scriptData == nil ? "Enable JIT" : "Enable and Run Script"
        case .killProcess:
            return "Kill Process"
        case .launchApp:
            return "Launch App"
        }
    }

    var role: ButtonRole? {
        switch self {
        case .enableJIT(let configuration):
            return configuration.scriptData == nil ? nil : .destructive
        case .killProcess:
            return .destructive
        case .launchApp:
            return nil
        }
    }

    private func targetDescription(for configuration: JITEnableConfiguration) -> String {
        if let bundleID = configuration.bundleID {
            return bundleID
        }
        if let pid = configuration.pid {
            return "process \(pid)"
        }
        return "the requested app"
    }
}
