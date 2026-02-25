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
        await ensureHeartbeat()
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
        let entries = FetchDeviceProcessList(&err) ?? []
        for item in entries {
            guard let dict = item as? NSDictionary,
                  let pidNum = dict["pid"] as? NSNumber else { continue }
            let name = dict["name"] as? String ?? ""
            let bID = dict["bundleID"] as? String ?? ""
            // Match by bundle ID first (most stable), then by name
            if let myBundle = bundleID, !myBundle.isEmpty, bID == myBundle {
                return pidNum.intValue
            }
            if name == displayName {
                return pidNum.intValue
            }
        }
        return nil
    }
}

struct RunningProcessQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [RunningProcessEntity] {
        // Always fetch fresh so PIDs are current
        await ensureHeartbeat()
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
        await ensureHeartbeat()
        return try fetchProcessEntities()
    }

    private func fetchProcessEntities() throws -> [RunningProcessEntity] {
        var err: NSError?
        let entries = FetchDeviceProcessList(&err) ?? []
        if let err { throw err }

        return entries.compactMap { item -> RunningProcessEntity? in
            guard let dict = item as? NSDictionary,
                  let pidNumber = dict["pid"] as? NSNumber else { return nil }
            let pid = pidNumber.intValue
            let name = dict["name"] as? String
            let bundleID = dict["bundleID"] as? String
            let path = dict["path"] as? String ?? ""

            let displayName: String
            if let name, !name.isEmpty {
                displayName = name
            } else if let bundleID, !bundleID.isEmpty {
                displayName = bundleID
            } else if let last = path.replacingOccurrences(of: "file://", with: "").split(separator: "/").last {
                displayName = String(last)
            } else {
                displayName = "Process \(pid)"
            }

            // Use bundleID as stable ID if available, otherwise fall back to name
            let stableID = (bundleID != nil && !bundleID!.isEmpty) ? bundleID! : displayName

            return RunningProcessEntity(id: stableID, pid: pid, displayName: displayName, bundleID: bundleID)
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

    @Parameter(title: "Process ID", description: "A specific PID to attach to instead of an app")
    var pid: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Enable JIT for \(\.$app)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let bundleID = app?.id

        guard bundleID != nil || pid != nil else {
            return .result(value: "Select an app or provide a PID.")
        }

        await ensureHeartbeat()

        var scriptData: Data? = nil
        var scriptName: String? = nil
        if let bundleID {
            if let preferred = IntentScriptResolver.preferredScript(for: bundleID) {
                scriptData = preferred.data
                scriptName = preferred.name
            }
        }

        var callback: DebugAppCallback? = nil
        if ProcessInfo.processInfo.hasTXM, let sd = scriptData {
            let name = scriptName ?? bundleID ?? "Script"
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
                DispatchQueue.global(qos: .background).async {
                    do { try model.runScript(data: sd, name: name) }
                    catch { LogManager.shared.addErrorLog("Script error: \(error.localizedDescription)") }
                }
            }
        }

        let logger: LogFunc = { message in
            if let message { LogManager.shared.addInfoLog(message) }
        }

        let success: Bool
        let target: String
        if let pid {
            target = "PID \(pid)"
            success = JITEnableContext.shared.debugApp(withPID: Int32(pid), logger: logger, jsCallback: callback)
        } else if let bundleID {
            target = app?.displayName ?? bundleID
            success = JITEnableContext.shared.debugApp(withBundleID: bundleID, logger: logger, jsCallback: callback)
        } else {
            return .result(value: "No target specified.")
        }

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
            await ensureHeartbeat()
        } else if let process {
            await ensureHeartbeat()

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

// MARK: - Shared Heartbeat Helper

func ensureHeartbeat() async {
    await MainActor.run {
        pubHeartBeat = false
        startHeartbeatInBackground(showErrorUI: false)
    }
    try? await Task.sleep(nanoseconds: 1_000_000_000)
}

// MARK: - Script Resolution (mirrors HomeView logic)

enum IntentScriptResolver {
    static func preferredScript(for bundleID: String) -> (data: Data, name: String)? {
        if let assigned = assignedScript(for: bundleID) {
            return assigned
        }
        return autoScript(for: bundleID)
    }

    private static func assignedScript(for bundleID: String) -> (data: Data, name: String)? {
        guard let mapping = UserDefaults.standard.dictionary(forKey: "BundleScriptMap") as? [String: String],
              let scriptName = mapping[bundleID] else { return nil }
        let scriptsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scripts")
        let scriptURL = scriptsDir.appendingPathComponent(scriptName)
        guard FileManager.default.fileExists(atPath: scriptURL.path),
              let data = try? Data(contentsOf: scriptURL) else { return nil }
        return (data, scriptName)
    }

    private static func autoScript(for bundleID: String) -> (data: Data, name: String)? {
        guard ProcessInfo.processInfo.hasTXM else { return nil }
        guard #available(iOS 26, *) else { return nil }
        let appName = (try? JITEnableContext.shared.getAppList()[bundleID]) ?? storedFavoriteName(for: bundleID)
        guard let appName,
              let resource = autoScriptResource(for: appName) else {
            return nil
        }
        let scriptsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scripts")
        let documentsURL = scriptsDir.appendingPathComponent(resource.fileName)
        if let data = try? Data(contentsOf: documentsURL) {
            return (data, resource.fileName)
        }
        guard let bundleURL = Bundle.main.url(forResource: resource.resource, withExtension: "js"),
              let data = try? Data(contentsOf: bundleURL) else {
            return nil
        }
        return (data, resource.fileName)
    }

    private static func storedFavoriteName(for bundleID: String) -> String? {
        let defaults = UserDefaults(suiteName: "group.com.stik.sj")
        let names = defaults?.dictionary(forKey: "favoriteAppNames") as? [String: String]
        return names?[bundleID]
    }

    private static func autoScriptResource(for appName: String) -> (resource: String, fileName: String)? {
        switch appName {
        case "maciOS":
            return ("maciOS", "maciOS.js")
        case "Amethyst", "MeloNX":
            return ("Amethyst-MeloNX", "Amethyst-MeloNX.js")
        case "Geode":
            return ("Geode", "Geode.js")
        case "Manic EMU":
            return ("manic", "manic.js")
        case "UTM", "DolphiniOS", "Flycast":
            return ("UTM-Dolphin", "UTM-Dolphin.js")
        default:
            return nil
        }
    }
}

// MARK: - Notification for JS Script UI

extension Notification.Name {
    static let intentJSScriptReady = Notification.Name("intentJSScriptReady")
}
