//
//  ProfileView.swift
//  StikDebug
//
//  Created by s s on 2025/11/29.
//
import SwiftUI
import UniformTypeIdentifiers

class Profile: ObservableObject {
    private static let dateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f
    }()
    let data: Data
    @Published var appName: String = "unknown"
    @Published var appId: String = "unknown"
    @Published var uuid: String
    @Published var expirationDate: Date? = nil
    @Published var plistDict: [String:Any]? = nil
    var decodeError: String? = nil

    init(data: Data) {
        self.data = data
        do {
            let plistData = try CMSDecoderHelper.decodeCMSData(data)
            let plistDict = try PropertyListSerialization.propertyList(from: plistData, format: nil)
            if let plistDict = plistDict as? [String:Any] {
                self.plistDict = plistDict
                self.appName = plistDict["AppIDName"] as? String ?? "unknown"
                if let entitlementsDict = plistDict["Entitlements"] as? [String:Any] {
                    self.appId = entitlementsDict["application-identifier"] as? String ?? "unknown"
                }
                self.expirationDate = plistDict["ExpirationDate"] as? Date
                self.uuid = plistDict["UUID"] as? String ?? UUID().uuidString
            } else {
                self.uuid = UUID().uuidString
            }
        } catch {
            self.decodeError = error.localizedDescription
            uuid = UUID().uuidString
        }
    }
    
    var formattedDate: String {
        get {
            if let expirationDate {
                return Profile.dateFormatter.string(from: expirationDate)
            } else {
                return "Unknown"
            }
        }
    }
    
    // from AltStore
    var dateColor: Color {
        get {
            guard let expirationDate else {
                return .secondary
            }
            let currentDate = Date()
            let numberOfDays = expirationDate.numberOfCalendarDays(since: currentDate)
            switch numberOfDays
            {
            case 2...3: return .refreshOrange
            case 4...5: return .refreshYellow
            case 6...: return .refreshGreen
            default: return .refreshRed
            }
        }
    }
}

struct ProfileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "mobileprovision")!] }
    
    var data: Data? = nil
    
    init() {}
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data ?? Data())
    }
}

// the following 2 extensions are from AltStore
extension Color {
    static let refreshRed = Color(red: 1.0, green: 0.231, blue: 0.188)
    static let refreshOrange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let refreshYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let refreshGreen = Color(red: 0.204, green: 0.780, blue: 0.348)
    
}

extension Date {
    func numberOfCalendarDays(since date: Date) -> Int
    {
        let today = Calendar.current.startOfDay(for: self)
        let previousDay = Calendar.current.startOfDay(for: date)
        
        let components = Calendar.current.dateComponents([.day], from: previousDay, to: today)
        return components.day!
    }
}

struct ProfileView: View {
    @State private var working = true
    @State private var isExporterPresented = false
    @State private var exportFileName = ""
    @State private var exportDoc = ProfileDocument()
    @State private var isImporterPresented = false
    
    @State private var alert = false
    @State private var alertTitle = ""
    @State private var alertMsg = ""
    @State private var alertSuccess = false
    @State private var entries: [AppProfileStatus] = []
    @State private var expandedApps: Set<String> = []
    @State private var notMatchedProfiles: [AppProfileStatus] = []

    @State private var confirmRemove = false
    @State private var removeTargetName: String = ""
    @State private var removeTargetUUID: String = ""
    
    
    var body: some View {
        NavigationStack {
            List {
                if working && entries.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading...")
                            Spacer()
                        }
                    }
                } else if entries.isEmpty && notMatchedProfiles.isEmpty {
                    Section {
                        Text("No profiles found.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                ForEach(entries) { entry in
                    Section {
                        // Header/Status Row
                        VStack(alignment: .leading, spacing: 4) {
                            if let match = entry.bestMatchingProfile {
                                HStack {
                                    Image(systemName: "clock")
                                    Text("Expires: \(match.profile.formattedDate)")
                                }
                                .foregroundStyle(match.profile.dateColor)
                                .font(.subheadline)
                            } else {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                    Text("No matching profile")
                                }
                                .font(.subheadline)
                                .foregroundColor(.refreshRed)
                            }
                            
                            Text(entry.id)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        
                        // Profiles
                        if let recent = entry.mostRecentProfile {
                            profileRow(match: recent, isMostRecent: true)
                        }
                        
                        if let best = entry.bestMatchingProfile, best.profile.uuid != entry.mostRecentProfile?.profile.uuid {
                            profileRow(match: best, isMostRecent: false)
                        }
                        
                        if entry.profileMatches.count > 1 {
                            let showMore = expandedApps.contains(entry.id)
                            let extraProfiles = entry.profileMatches.dropFirst(recentAndBestCount(for: entry))
                            
                            if !extraProfiles.isEmpty {
                                if showMore {
                                    ForEach(extraProfiles, id: \.profile.uuid) { match in
                                        profileRow(match: match, isMostRecent: false)
                                    }
                                }
                                
                                Button {
                                    withAnimation {
                                        if showMore { expandedApps.remove(entry.id) }
                                        else { expandedApps.insert(entry.id) }
                                    }
                                } label: {
                                    Label(showMore ? "Hide older profiles" : "Show \(extraProfiles.count) older profiles",
                                          systemImage: showMore ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    } header: {
                        Text(entry.name)
                    }
                }
                
                if !notMatchedProfiles.isEmpty {
                    Section("Other Profiles") {
                        ForEach(notMatchedProfiles) { entry in
                            VStack(alignment: .leading) {
                                Text(entry.id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.primary)
                            }
                            
                            ForEach(entry.profileMatches, id: \.profile.uuid) { match in
                                profileRow(match: match, isMostRecent: false)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("App Expiry")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    
                    Button {
                        Task { await loadData(force: true) }
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    
                }
            }
            .onAppear { Task { await loadData() } }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [UTType(filenameExtension: "mobileprovision")!],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleImport(result: result) }
            }
            .fileExporter(
                isPresented: $isExporterPresented,
                document: exportDoc,
                contentType: .data,
                defaultFilename: exportFileName
            ) { result in
                switch result {
                case .success(let url):
                    print("Saved at \(url)")
                case .failure(let error):
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
                .alert(alertTitle, isPresented: $alert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMsg)
        }
        .alert("Confirm Removal", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) {
                Task { await removeProfile(uuid: removeTargetUUID) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Remove profile for \(removeTargetName) (UUID: \(removeTargetUUID))?\nApps associated with this profile may become unavailable.")
        }
    }
    
    private func profileActionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
        .buttonStyle(.borderless)
    }
    
    private func recentAndBestCount(for entry: AppProfileStatus) -> Int {
        let distinctBest : Int
        if let bestMatchingProfile = entry.bestMatchingProfile, let recent = entry.mostRecentProfile {
            distinctBest = (bestMatchingProfile.profile.uuid != recent.profile.uuid) ? 1 : 0
        } else {
            distinctBest = 0
        }
        
        return 1 + distinctBest
    }
    
    private func profileRow(match: ProfileMatch, isMostRecent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(isMostRecent ? "Most Recent Profile" : "Profile")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text(match.profile.formattedDate)
                    .font(.caption.monospaced())
                    .foregroundStyle(match.profile.dateColor)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.profile.appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("UUID: \(match.profile.uuid)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                HStack(spacing: 16) {
                    profileActionButton(icon: "square.and.arrow.down", color: .blue) {
                        saveProfile(profile: match.profile)
                    }
                    profileActionButton(icon: "trash", color: .refreshRed) {
                        removeProfilePrompt(entry: match.profile)
                    }
                }
            }
            if !match.missingEntitlements.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Missing entitlements:")
                        .font(.caption)
                        .foregroundColor(.refreshRed)
                    ForEach(Array(formattedMissingLines(from: match.missingEntitlements).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .foregroundColor(.refreshRed)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Data loading
    
    private func loadData(force: Bool = false) async {
        if !force, !entries.isEmpty {
            working = false
            return
        }
        await MainActor.run { working = true }
        do {
            let (profiles, apps) = try await Task.detached(priority: .userInitiated) { () throws -> ([Profile], [SideloadedApp]) in
                let profileDatas = try JITEnableContext.shared.fetchAllProfiles()
                let parsedProfiles = profileDatas.map { Profile(data: $0) }
                let rawApps = try JITEnableContext.shared.getSideloadedApps()
                let parsedApps = rawApps.compactMap { item -> SideloadedApp? in
                    guard let dict = item as? [String: Any] else { return nil }
                    return SideloadedApp(dictionary: dict)
                }
                return (parsedProfiles, parsedApps)
            }.value

            let failedProfiles = profiles.filter { $0.decodeError != nil }
            let validProfiles = profiles.filter { $0.decodeError == nil }

            if !failedProfiles.isEmpty {
                let errors = failedProfiles.map { $0.decodeError ?? "Unknown error" }
                let uniqueErrors = Array(Set(errors))
                await MainActor.run {
                    alertTitle = "Failed to Decode \(failedProfiles.count) Profile\(failedProfiles.count == 1 ? "" : "s")"
                    alertMsg = uniqueErrors.joined(separator: "\n")
                    alert = true
                }
            }

            let groupedProfiles = Dictionary(grouping: validProfiles) { profileIdentifier(from: $0) }
                .mapValues { profiles in
                    profiles.sorted { lhs, rhs in
                        let leftDate = lhs.expirationDate ?? .distantPast
                        let rightDate = rhs.expirationDate ?? .distantPast
                        return leftDate > rightDate
                    }
                }
            
            let wildcardGroups = groupedProfiles.filter { $0.key.contains("*") }
            let appsSorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let computedEntries = appsSorted.map { app in
                let matches = profileMatches(for: app, groupedProfiles: groupedProfiles, wildcardProfiles: wildcardGroups)
                return AppProfileStatus(app: app, profileMatches: matches)
            }
            
            let appIds = apps.compactMap { $0.applicationIdentifier }
            notMatchedProfiles = groupedProfiles
                .filter { !appIds.contains($0.key) }
                .map { appId, profiles in
                    AppProfileStatus(appId: appId, profiles: profiles)
                }
            
            await MainActor.run {
                self.entries = computedEntries
                self.working = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Failed to load"
                alertMsg = error.localizedDescription
                alertSuccess = false
                alert = true
                working = false
            }
        }
    }
    
    
    private func profileMatches(for app: SideloadedApp, groupedProfiles: [String: [Profile]], wildcardProfiles: [String: [Profile]]) -> [ProfileMatch] {
        let targetIdentifier = app.applicationIdentifier ?? app.bundleId
        var collected: [Profile] = []
        if let direct = groupedProfiles[targetIdentifier] {
            collected.append(contentsOf: direct)
        }
        if targetIdentifier != app.bundleId, let bundleMatches = groupedProfiles[app.bundleId] {
            collected.append(contentsOf: bundleMatches)
        }
        for (pattern, profiles) in wildcardProfiles {
            if wildcardMatch(pattern, value: targetIdentifier) || wildcardMatch(pattern, value: app.bundleId) {
                collected.append(contentsOf: profiles)
            }
        }
        var seen = Set<String>()
        let uniqueProfiles = collected.filter { profile in
            guard !profile.uuid.isEmpty else { return false }
            let inserted = seen.insert(profile.uuid).inserted
            return inserted
        }
        let matches = uniqueProfiles.map { profile -> ProfileMatch in
            let profileEntitlements = entitlements(from: profile)
            let missing = missingEntitlements(appEntitlements: app.entitlements, profileEntitlements: profileEntitlements)
            return ProfileMatch(profile: profile, missingEntitlements: missing)
        }
        return matches.sorted { lhs, rhs in
            let leftDate = lhs.profile.expirationDate ?? .distantPast
            let rightDate = rhs.profile.expirationDate ?? .distantPast
            return leftDate > rightDate
        }
    }
    
    // MARK: - Entitlement helpers
    
    private func profileIdentifier(from profile: Profile) -> String {
        entitlements(from: profile)["application-identifier"] as? String ?? profile.appId
    }
    
    private func entitlements(from profile: Profile) -> [String: Any] {
        profile.plistDict?["Entitlements"] as? [String: Any] ?? [:]
    }
    
    private func missingEntitlements(appEntitlements: [String: Any], profileEntitlements: [String: Any]) -> [MissingNode] {
        var missing: [MissingNode] = []
        for (key, appValue) in appEntitlements {
            guard let profileValue = profileEntitlements[key] else {
                missing.append(MissingNode(name: key, children: []))
                continue
            }
            if let node = diffEntitlement(name: key, appValue: appValue, profileValue: profileValue) {
                missing.append(node)
            }
        }
        return missing.sorted { $0.name < $1.name }
    }
    
    private func diffEntitlement(name: String, appValue: Any, profileValue: Any) -> MissingNode? {
        switch (profileValue, appValue) {
        case let (p as String, a as String):
            return wildcardMatch(p, value: a) ? nil : MissingNode(name: name, children: [])
        case let (p as [Any], a as [Any]):
            let aStrings = a.compactMap { normalizedString(from: $0) }
            let pStrings = p.compactMap { normalizedString(from: $0) }
            let missingValues = aStrings.filter { target in
                !pStrings.contains(where: { wildcardMatch($0, value: target) })
            }
            guard !missingValues.isEmpty else { return nil }
            let children = missingValues.map { MissingNode(name: $0, children: []) }
            return MissingNode(name: name, children: children)
        case let (p as [Any], a):
            let aString = normalizedString(from: a)
            let pStrings = p.compactMap { normalizedString(from: $0) }
            if let aString, pStrings.contains(where: { wildcardMatch($0, value: aString) }) {
                return nil
            }
            return MissingNode(name: name, children: aString.map { [MissingNode(name: $0, children: [])] } ?? [])
        case let (p as [String: Any], a as [String: Any]):
            let childMissing = missingEntitlements(appEntitlements: a, profileEntitlements: p)
            return childMissing.isEmpty ? nil : MissingNode(name: name, children: childMissing)
        case let (p as NSNumber, a as NSNumber):
            return p == a ? nil : MissingNode(name: name, children: [])
        case let (p as Bool, a as Bool):
            return p == a ? nil : MissingNode(name: name, children: [])
        default:
            if let pObj = profileValue as? NSObject, let aObj = appValue as? NSObject, pObj == aObj {
                return nil
            }
            return MissingNode(name: name, children: [])
        }
    }
    
    private func wildcardMatch(_ pattern: String, value: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
        let regex = "^" + escaped + "$"
        return value.range(of: regex, options: .regularExpression) != nil
    }
    
    private func normalizedString(from value: Any) -> String? {
        if let str = value as? String { return str }
        if let num = value as? NSNumber { return num.stringValue }
        return nil
    }
    
    private func removeProfilePrompt(entry: Profile) {
        removeTargetName = entry.appName
        removeTargetUUID = entry.uuid
        confirmRemove = true
    }
    
    func saveProfile(profile: Profile) {
        exportFileName = "\(profile.appName).mobileprovision"
        exportDoc = ProfileDocument(data: profile.data)
        isExporterPresented = true
    }
    
    func removeProfile(uuid: String) async {
        working = true
        do {
            try JITEnableContext.shared.removeProfile(withUUID: uuid)
            alertMsg = "Profile removed successfully"
            alertTitle = "Success"
            alertSuccess = true
            alert = true
            // Reload profiles after removal
            await loadData(force: true)
        } catch {
            alertMsg = error.localizedDescription
            alertTitle = "Failed to Remove Profile"
            alertSuccess = false
            alert = true
        }
        working = false
    }
    
    func handleImport(result: Result<[URL], Error>) async {
        working = true
        do {
            let fileURL = try result.get().first
            guard let fileURL = fileURL else {
                throw NSError(domain: "ProfileView", code: -1, userInfo: [NSLocalizedDescriptionKey: "No file selected"])
            }
            
            // Start accessing security-scoped resource
            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            
            let profileData = try Data(contentsOf: fileURL)
            try JITEnableContext.shared.addProfile(profileData)
            
            alertMsg = "Profile added successfully"
            alertTitle = "Success"
            alertSuccess = true
            alert = true
            
            // Reload profiles after adding
            await loadData(force: true)
        } catch {
            alertMsg = error.localizedDescription
            alertTitle = "Failed to Add Profile"
            alertSuccess = false
            alert = true
        }
        working = false
    }
}

private struct MissingNode: Identifiable {
    let id = UUID()
    let name: String
    let children: [MissingNode]
}

private func formattedMissingLines(from nodes: [MissingNode]) -> [String] {
    var lines: [String] = []
    for node in nodes {
        lines.append(node.name)
        lines.append(contentsOf: formattedMissingChildren(node.children, indentLevel: 1))
    }
    return lines
}

private func formattedMissingChildren(_ children: [MissingNode], indentLevel: Int) -> [String] {
    var lines: [String] = []
    let prefix = String(repeating: "  ", count: max(indentLevel - 1, 0)) + "┗ "
    for child in children {
        lines.append(prefix + child.name)
        lines.append(contentsOf: formattedMissingChildren(child.children, indentLevel: indentLevel + 1))
    }
    return lines
}

private struct SideloadedApp: Identifiable {
    let id: String
    let name: String
    let bundleId: String
    let entitlements: [String: Any]
    
    var applicationIdentifier: String? {
        entitlements["application-identifier"] as? String
    }
    
    init?(dictionary: [String: Any]) {
        guard let bundleId = dictionary["CFBundleIdentifier"] as? String else { return nil }
        self.bundleId = bundleId
        self.id = bundleId
        let displayName = dictionary["CFBundleDisplayName"] as? String
        let name = dictionary["CFBundleName"] as? String
        self.name = displayName ?? name ?? bundleId
        self.entitlements = dictionary["Entitlements"] as? [String: Any] ?? [:]
    }
}

private struct ProfileMatch: Identifiable {
    let id: String
    let profile: Profile
    let missingEntitlements: [MissingNode]
    
    init(profile: Profile, missingEntitlements: [MissingNode]) {
        self.id = profile.uuid
        self.profile = profile
        self.missingEntitlements = missingEntitlements
    }
}

private struct AppProfileStatus: Identifiable {
    let id: String
    let name: String
    let bundleId: String
    let entitlements: [String: Any]
    let profileMatches: [ProfileMatch]
    
    var mostRecentProfile: ProfileMatch? { profileMatches.first }
    var bestMatchingProfile: ProfileMatch? { profileMatches.first(where: { $0.missingEntitlements.isEmpty }) }
    
    init(app: SideloadedApp, profileMatches: [ProfileMatch]) {
        self.id = app.id
        self.name = app.name
        self.bundleId = app.bundleId
        self.entitlements = app.entitlements
        self.profileMatches = profileMatches

    }
    
    init(appId: String, profiles:[Profile]) {
        self.id = appId
        self.name = "-"
        self.bundleId = appId
        self.profileMatches = profiles.map { ProfileMatch(profile: $0, missingEntitlements: []) }
        self.entitlements = [:]
    }
}
