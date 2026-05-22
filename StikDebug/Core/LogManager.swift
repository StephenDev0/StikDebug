//
//  LogManager.swift
//  StikDebug
//
//  Created by neoarz on 3/29/25.
//

import Foundation

final class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published var logs: [LogEntry] = []
    @Published var errorCount: Int = 0

    struct LogEntry: Identifiable, Sendable {
        let id: UUID
        let timestamp: Date
        let type: LogType
        let message: String

        enum LogType: String, Sendable {
            case info    = "INFO"
            case error   = "ERROR"
            case debug   = "DEBUG"
            case warning = "WARNING"
        }

        init(timestamp: Date, type: LogType, message: String) {
            self.id = UUID()
            self.timestamp = timestamp
            self.type = type
            self.message = message
        }
    }

    private static let redundantPrefixes: [String] = [
        "Info: ", "INFO: ", "Information: ",
        "Error: ", "ERROR: ", "ERR: ",
        "Debug: ", "DEBUG: ", "DBG: ",
        "Warning: ", "WARN: ", "WARNING: "
    ]

    private init() {
        addInfoLog("StikDebug starting up")
        addInfoLog("Initializing environment")
    }

    func addLog(message: String, type: LogEntry.LogType) {
        let clean = Self.redundantPrefixes
            .first(where: { message.hasPrefix($0) })
            .map { String(message.dropFirst($0.count)) } ?? message

        DispatchQueue.main.async {
            self.logs.append(LogEntry(timestamp: Date(), type: type, message: clean))
            if type == .error { self.errorCount += 1 }
            if self.logs.count > 1000 { self.logs.removeFirst(100) }
        }
    }

    func addInfoLog(_ message: String)    { addLog(message: message, type: .info) }
    func addErrorLog(_ message: String)   { addLog(message: message, type: .error) }
    func addDebugLog(_ message: String)   { addLog(message: message, type: .debug) }
    func addWarningLog(_ message: String) { addLog(message: message, type: .warning) }

    func setLogs(_ entries: [LogEntry]) {
        DispatchQueue.main.async {
            self.logs = entries
            self.errorCount = entries.filter { $0.type == .error }.count
        }
    }

    func appendLogs(_ entries: [LogEntry], maxTotal: Int = 1000) {
        DispatchQueue.main.async {
            self.logs.append(contentsOf: entries)
            self.errorCount += entries.filter { $0.type == .error }.count
            if self.logs.count > maxTotal {
                let excess = self.logs.count - maxTotal
                let removed = self.logs.prefix(excess)
                self.logs.removeFirst(excess)
                let removedErrors = removed.filter { $0.type == .error }.count
                self.errorCount = max(0, self.errorCount - removedErrors)
            }
        }
    }

    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.errorCount = 0
        }
    }
}
