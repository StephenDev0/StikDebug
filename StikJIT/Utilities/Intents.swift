import AppIntents
import Foundation

// MARK: - Installed App Entity

struct InstalledAppEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Installed App",
        numericFormat: "\(placeholder: .int) apps"
    )
    static var defaultQuery = InstalledAppQuery()

    var id: String // bundle ID
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(id)")
    }
}

struct InstalledAppQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [InstalledAppEntity] {
        let allApps = (try? JITEnableContext.shared.getAppList()) ?? [:]
        return identifiers.compactMap { bundleID in
            guard let name = allApps[bundleID] else { return nil }
            return InstalledAppEntity(id: bundleID, displayName: name)
        }
    }

    func entities(matching string: String) async throws -> [InstalledAppEntity] {
        let all = try await suggestedEntities()
        guard !string.isEmpty else { return all }
        let lower = string.lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(lower) ||
            $0.id.lowercased().contains(lower)
        }
    }

    func suggestedEntities() async throws -> [InstalledAppEntity] {
        await ensureTunnel()
        let allApps = (try? JITEnableContext.shared.getAppList()) ?? [:]
        return allApps.map { InstalledAppEntity(id: $0.key, displayName: $0.value) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

// MARK: - Running Process Entity

struct RunningProcessEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Running Process",
        numericFormat: "\(placeholder: .int) processes"
    )
    static var defaultQuery = RunningProcessQuery()

    // Use a stable identifier (bundleID or name) so the entity survives PID changes
    var id: String
    var pid: Int
    var displayName: String
    var bundleID: String?

    var displayRepresentation: DisplayRepresentation {
        let subtitle: String
        if let bundleID, !bundleID.isEmpty {
            subtitle = "\(bundleID) — PID \(pid)"
        } else {
            subtitle = "PID \(pid)"
        }
        return DisplayRepresentation(title: "\(displayName)", subtitle: "\(subtitle)")
    }

    /// Resolve the current PID for this process by re-fetching the process list.
    func resolveCurrentPID() -> Int? {
        var err: NSError?
        let entries = ProcessInfoEntry.currentEntries(&err)
        for item in entries {
            // Match by bundle ID first (most stable), then by name
            if let myBundle = bundleID, !myBundle.isEmpty, item.bundleID == myBundle {
                return item.pid
            }
            if item.displayName == displayName {
                return item.pid
            }
        }
        return nil
    }
}

struct RunningProcessQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [RunningProcessEntity] {
        // Always fetch fresh so PIDs are current
        await ensureTunnel()
        let all = try fetchProcessEntities()
        let idSet = Set(identifiers)
        return all.filter { idSet.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [RunningProcessEntity] {
        let all = try await suggestedEntities()
        guard !string.isEmpty else { return all }
        let lower = string.lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(lower) ||
            ($0.bundleID?.lowercased().contains(lower) ?? false) ||
            "\($0.pid)".contains(string)
        }
    }

    func suggestedEntities() async throws -> [RunningProcessEntity] {
        await ensureTunnel()
        return try fetchProcessEntities()
    }

    private func fetchProcessEntities() throws -> [RunningProcessEntity] {
        var err: NSError?
        let entries = ProcessInfoEntry.currentEntries(&err)
        if let err { throw err }

        return entries.map { entry in
            RunningProcessEntity(
                id: entry.stableIdentifier,
                pid: entry.pid,
                displayName: entry.displayName,
                bundleID: entry.bundleID
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

// MARK: - Enable JIT Intent

struct EnableJITIntent: AppIntent, ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Enable JIT"
    static var description = IntentDescription(
        "Enables JIT compilation for an installed app using StikDebug.",
        categoryName: "StikDebug"
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "App", description: "The app to enable JIT for",
               requestValueDialog: "Which app would you like to enable JIT for?")
    var app: InstalledAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Enable JIT for \(\.$app)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let bundleID = app?.id else {
            return .result(value: "Select an app to enable JIT for.")
        }

        await ensureTunnel()

        var scriptData: Data? = nil
        var scriptName: String? = nil
        if let preferred = ScriptStore.preferredScript(for: bundleID) {
            scriptData = preferred.data
            scriptName = preferred.name
        }

        var callback: DebugAppCallback? = nil
        if ProcessInfo.processInfo.hasTXM, let sd = scriptData {
            let name = scriptName ?? bundleID
            callback = { pid, debugProxyHandle, remoteServerHandle, semaphore in
                let model = RunJSViewModel(
                    pid: Int(pid),
                    debugProxy: debugProxyHandle,
                    remoteServer: remoteServerHandle,
                    semaphore: semaphore
                )
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .intentJSScriptReady,
                        object: nil,
                        userInfo: ["model": model, "scriptData": sd, "scriptName": name]
                    )
                }
                do { try model.runScript(data: sd, name: name) }
                catch {
                    semaphore.signal()
                    LogManager.shared.addErrorLog("Script error: \(error.localizedDescription)")
                }
            }
        }

        let logger: LogFunc = { message in
            if let message { LogManager.shared.addInfoLog(message) }
        }

        let target = app?.displayName ?? bundleID
        let success = JITEnableContext.shared.debugApp(withBundleID: bundleID, logger: logger, jsCallback: callback)

        if success {
            LogManager.shared.addInfoLog("JIT enabled for \(target) via Shortcut")
            return .result(value: "Successfully enabled JIT for \(target).")
        } else {
            LogManager.shared.addErrorLog("Failed to enable JIT for \(target) via Shortcut")
            return .result(value: "Failed to enable JIT for \(target).")
        }
    }
}

// MARK: - Kill Process Intent

struct KillProcessIntent: AppIntent {
    static var title: LocalizedStringResource = "Kill Process"
    static var description = IntentDescription(
        "Terminates a running process on the device using StikDebug.",
        categoryName: "StikDebug"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Process", description: "The process to terminate",
               requestValueDialog: "Which process would you like to kill?")
    var process: RunningProcessEntity?

    @Parameter(title: "Process ID", description: "A specific PID to kill instead of selecting a process")
    var pid: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Kill \(\.$process)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let targetPID: Int
        let targetName: String

        if let pid {
            targetPID = pid
            targetName = "PID \(pid)"
            await ensureTunnel()
        } else if let process {
            await ensureTunnel()

            // Always re-resolve to get the current PID — the stored one may be stale
            guard let resolved = process.resolveCurrentPID() else {
                return .result(value: "\(process.displayName) is no longer running.")
            }
            targetPID = resolved
            targetName = process.displayName
        } else {
            return .result(value: "Select a process or provide a PID.")
        }

        var err: NSError?
        let success = KillDeviceProcess(Int32(targetPID), &err)

        if success {
            LogManager.shared.addInfoLog("Killed \(targetName) via Shortcut")
            return .result(value: "Successfully killed \(targetName).")
        } else {
            let reason = err?.localizedDescription ?? "Unknown error"
            LogManager.shared.addErrorLog("Failed to kill \(targetName) via Shortcut: \(reason)")
            return .result(value: "Failed to kill \(targetName): \(reason)")
        }
    }
}

// MARK: - Shortcuts Provider

struct StikDebugShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: EnableJITIntent(),
            phrases: [
                "Enable JIT for \(\.$app) with \(.applicationName)",
                "Enable JIT for \(\.$app) using \(.applicationName)",
                "Enable JIT for \(\.$app) in \(.applicationName)",
                "\(.applicationName) enable JIT for \(\.$app)",
                "\(.applicationName) enable JIT",
                "Use \(.applicationName) to enable JIT for \(\.$app)",
                "Use \(.applicationName) to enable JIT"
            ],
            shortTitle: "Enable JIT",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: KillProcessIntent(),
            phrases: [
                "Kill \(\.$process) with \(.applicationName)",
                "Kill \(\.$process) using \(.applicationName)",
                "Kill \(\.$process) in \(.applicationName)",
                "\(.applicationName) kill \(\.$process)",
                "\(.applicationName) kill process",
                "Use \(.applicationName) to kill \(\.$process)",
                "Use \(.applicationName) to stop \(\.$process)"
            ],
            shortTitle: "Kill Process",
            systemImageName: "xmark.circle.fill"
        )
    }
}

// MARK: - Shared Tunnel Helper

func ensureTunnel() async {
    await MainActor.run {
        pubTunnelConnected = false
        startTunnelInBackground(showErrorUI: false)
    }
    try? await Task.sleep(nanoseconds: 1_000_000_000)
}
