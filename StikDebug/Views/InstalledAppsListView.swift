//
//  InstalledAppsListView.swift
//  StikDebug
//
//  Created by Stossy11 on 28/03/2025.
//

import SwiftUI
import UIKit
import WidgetKit

struct InstalledAppsListView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelectApp: (String, String) -> Void
    let showDoneButton: Bool
    let onImportPairingFile: (() -> Void)?

    private let sharedDefaults = UserDefaults(suiteName: ScriptStore.favoriteAppNamesSuiteName) ?? .standard

    @StateObject private var viewModel = InstalledAppsViewModel()

    @AppStorage("recentApps") private var recentApps: [String] = []
    @AppStorage("favoriteApps") private var favoriteApps: [String] = [] {
        didSet {
            favoriteApps = Array(favoriteApps.prefix(Self.maxFavorites))
            persistIfChanged()
        }
    }
    @AppStorage("loadAppIconsOnJIT") private var loadAppIconsOnJIT = true
    @AppStorage("pinnedSystemApps") private var pinnedSystemApps: [String] = []
    @AppStorage("pinnedSystemAppNames") private var pinnedSystemAppNames: [String: String] = [:]

    @State private var launchingBundles: Set<String> = []
    @State private var launchFeedback: LaunchFeedback?
    @State private var debuggableSearchText = ""
    @State private var launchSearchText = ""
    @State private var prefetchedBundleIDs: Set<String> = []
    @State private var selectedTab: AppListTab = .debuggable

    private static let maxFavorites = 4
    private static let maxSystemPins = 8
    private static let iconPrefetchLimit = 32

    init(
        onSelectApp: @escaping (String, String) -> Void,
        showDoneButton: Bool = true,
        onImportPairingFile: (() -> Void)? = nil
    ) {
        self.onSelectApp = onSelectApp
        self.showDoneButton = showDoneButton
        self.onImportPairingFile = onImportPairingFile
    }

    var body: some View {
        NavigationStack {
            tabContent(for: selectedTab)
                .transition(.opacity)
                .transaction { transaction in
                    transaction.disablesAnimations = true
                }
                .navigationTitle(selectedTab.navigationTitle)
                .searchable(
                    text: currentSearchBinding,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: selectedTab.searchPrompt
                )
                .toolbar {
                    tabPickerToolbarItem
                    leadingToolbarItem
                    trailingToolbarItem
                }
        }
        .overlay {
            launchFeedbackOverlay
        }
        .onAppear(perform: refreshIconPrefetch)
        .onChange(of: favoriteApps) { _, _ in prefetchPriorityIcons() }
        .onChange(of: recentApps) { _, _ in prefetchPriorityIcons() }
        .onChange(of: selectedTab) { _, _ in prefetchPriorityIcons() }
        .onChange(of: pinnedSystemApps) { _, _ in prefetchPriorityIcons() }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            handleLoadingChange(isLoading)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pairingFileImported)) { _ in
            viewModel.refreshAppLists()
        }
    }

    private var currentSearchBinding: Binding<String> {
        Binding(
            get: { selectedTab == .debuggable ? debuggableSearchText : launchSearchText },
            set: { searchText in
                if selectedTab == .debuggable {
                    debuggableSearchText = searchText
                } else {
                    launchSearchText = searchText
                }
            }
        )
    }

    private var debuggableSnapshot: DebuggableAppListSnapshot {
        let query = InstalledAppListItem.normalized(debuggableSearchText)
        let filteredApps = query.isEmpty
            ? viewModel.debuggableItems
            : viewModel.debuggableItems.filter { $0.matches(query) }
        let filteredBundleIDs = Set(filteredApps.map(\.bundleID))

        return DebuggableAppListSnapshot(
            apps: filteredApps,
            favoriteBundles: favoriteApps.filter { filteredBundleIDs.contains($0) },
            recentBundles: recentApps.filter { filteredBundleIDs.contains($0) && !favoriteApps.contains($0) },
            searchIsActive: !query.isEmpty
        )
    }

    private var launchSnapshot: LaunchAppListSnapshot {
        let query = InstalledAppListItem.normalized(launchSearchText)
        let filteredApps = query.isEmpty
            ? viewModel.launchItems
            : viewModel.launchItems.filter { $0.matches(query) }

        return LaunchAppListSnapshot(
            apps: filteredApps,
            searchIsActive: !query.isEmpty
        )
    }

    @ToolbarContentBuilder
    private var tabPickerToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("", selection: $selectedTab) {
                ForEach(AppListTab.allCases) { tab in
                    Text(tab.title.localized).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
    }

    @ToolbarContentBuilder
    private var leadingToolbarItem: some ToolbarContent {
        if let onImportPairingFile {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onImportPairingFile) {
                    Image(systemName: "doc.badge.plus")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if showDoneButton {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            } else {
                Button {
                    viewModel.refreshAppLists()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    @ViewBuilder
    private var launchFeedbackOverlay: some View {
        if let launchFeedback {
            VStack {
                Spacer()
                Text(launchFeedback.message)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .foregroundStyle(launchFeedback.success ? .green : .red)
                    .shadow(radius: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 40)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: launchFeedback.id)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppListTab) -> some View {
        switch tab {
        case .debuggable:
            debuggableAppsList
        case .launch:
            launchAppsList
        }
    }

    private var debuggableAppsList: some View {
        let snapshot = debuggableSnapshot

        return List {
            errorSection

            if snapshot.apps.isEmpty && !viewModel.isLoading {
                EmptyAppListState(
                    systemImage: snapshot.searchIsActive ? "text.magnifyingglass" : "magnifyingglass",
                    title: snapshot.searchIsActive ? "No matching apps".localized : "No JIT Apps Found".localized,
                    message: snapshot.searchIsActive
                        ? "Try a different name or bundle identifier.".localized
                        : "StikDebug can only connect to apps with the \"get-task-allow\" entitlement.".localized
                )
            } else {
                debuggableAppSections(snapshot: snapshot)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var launchAppsList: some View {
        let snapshot = launchSnapshot

        return List {
            errorSection

            if snapshot.apps.isEmpty {
                EmptyAppListState(
                    systemImage: "magnifyingglass",
                    title: snapshot.searchIsActive ? "No matches".localized : "No Apps Found".localized,
                    message: snapshot.searchIsActive
                        ? "Try another name or bundle identifier.".localized
                        : "Once your device pairing file is imported and CoreDevice is connected, all apps will appear here.".localized
                )
            } else {
                launchAppSection(snapshot: snapshot)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.lastError {
            Section {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func debuggableAppSections(snapshot: DebuggableAppListSnapshot) -> some View {
        if !snapshot.favoriteBundles.isEmpty {
            Section(String(format: "Favorites (%d/4)".localized, snapshot.favoriteBundles.count)) {
                ForEach(snapshot.favoriteBundles, id: \.self) { bundleID in
                    debugAppRow(
                        bundleID: bundleID,
                        appName: viewModel.displayName(for: bundleID) ?? fallbackReadableName(from: bundleID)
                    )
                }
            }
        }

        if !snapshot.recentBundles.isEmpty {
            Section("Recents".localized) {
                ForEach(snapshot.recentBundles, id: \.self) { bundleID in
                    debugAppRow(
                        bundleID: bundleID,
                        appName: viewModel.displayName(for: bundleID) ?? fallbackReadableName(from: bundleID)
                    )
                }
            }
        }

        Section("Apps with get-task-allow".localized) {
            ForEach(snapshot.apps) { app in
                debugAppRow(bundleID: app.bundleID, appName: app.name)
            }
        }
    }

    private func launchAppSection(snapshot: LaunchAppListSnapshot) -> some View {
        Section("All Apps".localized) {
            ForEach(snapshot.apps) { app in
                let isPinned = pinnedSystemApps.contains(app.bundleID)

                LaunchAppRow(
                    bundleID: app.bundleID,
                    appName: app.name,
                    isLaunching: launchingBundles.contains(app.bundleID)
                ) {
                    startLaunching(bundleID: app.bundleID, appName: app.name)
                }
                .overlay(alignment: .topTrailing) {
                    if isPinned {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .padding(6)
                            .accessibilityHidden(true)
                    }
                }
                .contextMenu {
                    Button((isPinned ? "Remove from Home" : "Add to Home").localized,
                           systemImage: isPinned ? "star.slash" : "star") {
                        toggleSystemPin(bundleID: app.bundleID, appName: app.name)
                    }
                    Button("Copy Bundle ID".localized, systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = app.bundleID
                        Haptics.light()
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        toggleSystemPin(bundleID: app.bundleID, appName: app.name)
                    } label: {
                        Label((isPinned ? "Unpin" : "Pin").localized, systemImage: "star")
                    }
                    .tint(.yellow)
                }
            }
        }
    }

    private func debugAppRow(bundleID: String, appName: String) -> some View {
        AppButton(
            bundleID: bundleID,
            appName: appName,
            recentApps: $recentApps,
            favoriteApps: $favoriteApps,
            onSelectApp: onSelectApp,
            sharedDefaults: sharedDefaults
        )
    }

    private func refreshIconPrefetch() {
        prefetchedBundleIDs.removeAll()
        prefetchPriorityIcons()
    }

    private func handleLoadingChange(_ isLoading: Bool) {
        if isLoading {
            prefetchedBundleIDs.removeAll()
        } else {
            prefetchPriorityIcons()
            persistIfChanged()
        }
    }

    private func prefetchPriorityIcons(limit: Int = Self.iconPrefetchLimit) {
        guard loadAppIconsOnJIT else {
            return
        }

        var priorityBundleIDs: [String] = []
        var seenBundleIDs = Set<String>()

        func appendUnique<S: Sequence>(_ bundleIDs: S) where S.Element == String {
            guard priorityBundleIDs.count < limit else { return }

            for bundleID in bundleIDs {
                guard seenBundleIDs.insert(bundleID).inserted else { continue }
                priorityBundleIDs.append(bundleID)
                if priorityBundleIDs.count >= limit { break }
            }
        }

        appendUnique(favoriteApps)
        appendUnique(recentApps)
        appendUnique(pinnedSystemApps)
        appendUnique(viewModel.debuggableItems.map(\.bundleID))
        appendUnique(viewModel.launchItems.map(\.bundleID))

        let bundleIDsToPrefetch = priorityBundleIDs.filter { !prefetchedBundleIDs.contains($0) }
        guard !bundleIDsToPrefetch.isEmpty else {
            return
        }

        prefetchedBundleIDs.formUnion(bundleIDsToPrefetch)
        AppIconRepository.prefetch(bundleIDs: bundleIDsToPrefetch)
    }

    private func persistIfChanged() {
        var touched = false
        let previousRecents = (sharedDefaults.array(forKey: "recentApps") as? [String]) ?? []
        let previousFavorites = (sharedDefaults.array(forKey: "favoriteApps") as? [String]) ?? []
        let previousPinned = (sharedDefaults.array(forKey: "pinnedSystemApps") as? [String]) ?? []
        let previousPinnedNames = (sharedDefaults.dictionary(forKey: "pinnedSystemAppNames") as? [String: String]) ?? [:]
        let previousFavoriteNames = (sharedDefaults.dictionary(forKey: ScriptStore.favoriteAppNamesKey) as? [String: String]) ?? [:]

        if previousRecents != recentApps {
            sharedDefaults.set(recentApps, forKey: "recentApps")
            touched = true
        }
        if previousFavorites != favoriteApps {
            sharedDefaults.set(favoriteApps, forKey: "favoriteApps")
            touched = true
        }
        if previousPinned != pinnedSystemApps {
            sharedDefaults.set(pinnedSystemApps, forKey: "pinnedSystemApps")
            touched = true
        }
        if previousPinnedNames != pinnedSystemAppNames {
            sharedDefaults.set(pinnedSystemAppNames, forKey: "pinnedSystemAppNames")
            touched = true
        }

        let favoriteNames = Dictionary(uniqueKeysWithValues: favoriteApps.map { bundleID in
            (bundleID, viewModel.displayName(for: bundleID) ?? fallbackReadableName(from: bundleID))
        })

        if previousFavoriteNames != favoriteNames {
            sharedDefaults.set(favoriteNames, forKey: ScriptStore.favoriteAppNamesKey)
            touched = true
        }

        if touched {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func startLaunching(bundleID: String, appName: String) {
        guard !launchingBundles.contains(bundleID) else {
            return
        }

        launchingBundles.insert(bundleID)
        Haptics.selection()
        AccessibilityAnnouncer.announce(String(format: "Launching %@".localized, appName))

        viewModel.launchWithoutDebug(bundleID: bundleID) { success in
            launchingBundles.remove(bundleID)

            let message = success
                ? String(format: "Launch request sent for %@".localized, appName)
                : String(format: "Launch failed for %@".localized, appName)
            let feedback = LaunchFeedback(message: message, success: success)

            if success {
                Haptics.light()
            }

            AccessibilityAnnouncer.announce(message)
            withAnimation {
                launchFeedback = feedback
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if launchFeedback?.id == feedback.id {
                    withAnimation {
                        launchFeedback = nil
                    }
                }
            }
        }
    }

    private func toggleSystemPin(bundleID: String, appName: String) {
        Haptics.light()

        if let index = pinnedSystemApps.firstIndex(of: bundleID) {
            pinnedSystemApps.remove(at: index)
            pinnedSystemAppNames.removeValue(forKey: bundleID)
        } else {
            pinnedSystemApps.removeAll { $0 == bundleID }
            pinnedSystemApps.insert(bundleID, at: 0)
            pinnedSystemAppNames[bundleID] = appName

            if pinnedSystemApps.count > Self.maxSystemPins {
                let surplus = Array(pinnedSystemApps.suffix(from: Self.maxSystemPins))
                for bundleID in surplus {
                    pinnedSystemAppNames.removeValue(forKey: bundleID)
                }
                pinnedSystemApps = Array(pinnedSystemApps.prefix(Self.maxSystemPins))
            }
        }

        persistIfChanged()
    }

    private func fallbackReadableName(from bundleID: String) -> String {
        let components = bundleID.split(separator: ".")
        if let lastComponent = components.last {
            let cleaned = lastComponent.replacingOccurrences(of: "_", with: " ")
            let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed.capitalized
            }
        }

        return bundleID
    }
}

private enum AppListTab: Int, CaseIterable, Identifiable {
    case debuggable
    case launch

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .debuggable:
            return "JIT"
        case .launch:
            return "Other"
        }
    }

    var navigationTitle: String {
        switch self {
        case .debuggable:
            return "Enable JIT".localized
        case .launch:
            return "Launch Apps".localized
        }
    }

    var searchPrompt: String {
        switch self {
        case .debuggable:
            return "Search apps or bundle ID".localized
        case .launch:
            return "Search".localized
        }
    }
}

private struct LaunchFeedback: Identifiable {
    let id = UUID()
    let message: String
    let success: Bool
}

private struct DebuggableAppListSnapshot {
    let apps: [InstalledAppListItem]
    let favoriteBundles: [String]
    let recentBundles: [String]
    let searchIsActive: Bool
}

private struct LaunchAppListSnapshot {
    let apps: [InstalledAppListItem]
    let searchIsActive: Bool
}

private struct EmptyAppListState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .listRowBackground(Color.clear)
        }
    }
}

struct InstalledAppsListView_Previews: PreviewProvider {
    static var previews: some View {
        InstalledAppsListView { _, _ in }
            .environment(\.colorScheme, .dark)
    }
}
