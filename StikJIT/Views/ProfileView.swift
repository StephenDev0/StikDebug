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
            appName = "Failed to decode this profile."
            appId = error.localizedDescription
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
    
    @State private var searchText = ""
    @State private var alert = false
    @State private var alertTitle = ""
    @State private var alertMsg = ""
    @State private var alertSuccess = false
    
    @State private var profiles: [Profile] = []
    @State private var confirmRemove = false
    @State private var removeTargetName: String = ""
    @State private var removeTargetUUID: String = ""
    @State private var expandedAppIds: Set<String> = []
    
    // Computed property to group profiles by appId and sort by expiration date
    private var groupedProfiles: [String: [Profile]] {
        Dictionary(grouping: profiles, by: { $0.appId })
            .mapValues { profiles in
                profiles.sorted { profile1, profile2 in
                    // Sort by expiration date descending (latest first)
                    guard let date1 = profile1.expirationDate else { return false }
                    guard let date2 = profile2.expirationDate else { return true }
                    return date1 > date2
                }
            }
    }
    
    private var sortedAppIds: [String] {
        groupedProfiles.keys.sorted()
    }
    
    
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.themeExpansionManager) private var themeExpansion
    private var backgroundStyle: BackgroundStyle { themeExpansion?.backgroundStyle(for: appThemeRaw) ?? AppTheme.system.backgroundStyle }
    private var preferredScheme: ColorScheme? { themeExpansion?.preferredColorScheme(for: appThemeRaw) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground(style: backgroundStyle)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        infoCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }
                
                if alert {
                    CustomErrorView(title: alertTitle,
                                    message: alertMsg,
                                    onDismiss: { alert = false },
                                    messageType: alertSuccess ? .success : .error)
                }
                
                if confirmRemove {
                    CustomErrorView(
                        title: "Confirm Removal",
                        message: "Remove profile for \(removeTargetName) (UUID: \(removeTargetUUID))?\n**Apps associated this profile may become unavailable.**",
                        onDismiss: { confirmRemove = false },
                        showButton: true,
                        primaryButtonText: "Remove",
                        secondaryButtonText: "Cancel",
                        onPrimaryButtonTap: {
                            Task { await removeProfile(uuid: removeTargetUUID) }
                        },
                        onSecondaryButtonTap: {
                            // Just dismiss
                        },
                        showSecondaryButton: true,
                        messageType: .info
                    )
                }
                
            }
            .navigationTitle("Profiles")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    
                    Button {
                        Task {await loadProfiles()}
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    
                }
            }
            
            .onAppear { Task { await loadProfiles() } }
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
        .preferredColorScheme(preferredScheme)
    }
    
    // MARK: - UI Sections
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            if profiles.isEmpty {
                Text(working ? "Loading Profiles" : "No profile available")
            } else {
                ForEach(sortedAppIds, id: \.self) { appId in
                    if let appProfiles = groupedProfiles[appId] {
                        VStack(alignment: .leading, spacing: 8) {
                            // App ID header with expand/collapse control
                            HStack {
                                Text(appId)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                if appProfiles.count > 1 {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            if expandedAppIds.contains(appId) {
                                                expandedAppIds.remove(appId)
                                            } else {
                                                expandedAppIds.insert(appId)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: expandedAppIds.contains(appId) ? "chevron.up" : "chevron.down")
                                        }
                                    }
                                }
                            }
                            .padding(.top, appId != sortedAppIds.first ? 8 : 0)
                            
                            // Profiles for this app (only first if collapsed)
                            let displayProfiles: [Profile] = expandedAppIds.contains(appId) ? appProfiles : Array(appProfiles.prefix(1))
                            ForEach(Array(displayProfiles.enumerated()), id: \.element.uuid) { pair in
                                let index = pair.offset
                                let entry = pair.element
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(entry.appName).bold()
                                        Text(entry.uuid).lineLimit(1)
                                        Text("Expires: \(entry.formattedDate)")
                                            .foregroundStyle(index == 0 ? entry.dateColor : Color.secondary)
                                    }
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                                    Spacer()
                                    HStack(spacing: 12) {
                                        Button { saveProfile(profile: entry) } label: { Image(systemName: "square.and.arrow.down") }
                                        Button(role: .destructive) {
                                            removeTargetName = entry.appName
                                            removeTargetUUID = entry.uuid
                                            confirmRemove = true
                                        } label: { Image(systemName: "trash") }
                                    }
                                }
                                .padding(.vertical, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                if entry.uuid != displayProfiles.last?.uuid {
                                    Divider().background(Color.white.opacity(0.08))
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: expandedAppIds)
                        }
                        
                        // Divider between app groups
                        if appId != sortedAppIds.last {
                            Divider()
                                .background(Color.white.opacity(0.12))
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
    
    func loadProfiles() async {
        working = true
        do {
            let profileDatas = try JITEnableContext.shared.fetchAllProfiles()
            self.profiles = profileDatas.map { Profile(data: $0) }
        } catch {
            alertMsg = error.localizedDescription
            alertTitle = "Failed to Fetch Profiles"
            alertSuccess = false
            alert = true
        }
        working = false
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
            await loadProfiles()
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
            await loadProfiles()
        } catch {
            alertMsg = error.localizedDescription
            alertTitle = "Failed to Add Profile"
            alertSuccess = false
            alert = true
        }
        working = false
    }
    
}
