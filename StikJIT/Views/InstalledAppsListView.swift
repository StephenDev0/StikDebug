//
//  InstalledAppsListView.swift
//  StikJIT
//
//  Created by Stossy11 on 28/03/2025.
//

import SwiftUI
import UIKit
import WidgetKit
import Combine

// MARK: - Installed Apps List

struct InstalledAppsListView: View {
    @StateObject private var viewModel = InstalledAppsViewModel()

    private let sharedDefaults = UserDefaults(suiteName: ScriptStore.favoriteAppNamesSuiteName) ?? .standard

    @AppStorage("recentApps") private var recentApps: [String] = []
    @AppStorage("favoriteApps") private var favoriteApps: [String] = [] {
        didSet {
            if favoriteApps.count > 4 {
                favoriteApps = Array(favoriteApps.prefix(4))
            }
            persistIfChanged()
        }
    }

    @AppStorage("loadAppIconsOnJIT") private var loadAppIconsOnJIT = true
    private let performanceMode = true
    @State private var launchingBundles: Set<String> = []
    @State private var launchFeedback: LaunchFeedback? = nil
    @State private var debuggableSearchText: String = ""
    @State private var launchSearchText: String = ""
    @State private var prefetchedBundleIDs: Set<String> = []
    @State private var selectedTab: AppListTab = .debuggable
    @AppStorage("pinnedSystemApps") private var pinnedSystemApps: [String] = []
    @AppStorage("pinnedSystemAppNames") private var pinnedSystemAppNames: [String: String] = [:]

    @Environment(\.dismiss) private var dismiss
    var onSelectApp: (String) -> Void
    var showDoneButton: Bool = true
    var onImportPairingFile: (() -> Void)? = nil


    private var currentSearchBinding: Binding<String> {
        Binding(
            get: { selectedTab == .debuggable ? debuggableSearchText : launchSearchText },
            set: {
                if selectedTab == .debuggable { debuggableSearchText = $0 }
                else { launchSearchText = $0 }
            }
        )
    }

    private var debuggableSearchIsActive: Bool {
        !debuggableSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var debuggableSortedApps: [(key: String, value: String)] {
        viewModel.debuggableApps.sorted { lhs, rhs in
            let comparison = lhs.value.localizedCaseInsensitiveCompare(rhs.value)
            if comparison == .orderedSame {
                return lhs.key < rhs.key
            }
            return comparison == .orderedAscending
        }
    }

    private var filteredDebuggableApps: [(key: String, value: String)] {
        guard debuggableSearchIsActive else { return debuggableSortedApps }
        let query = normalizedSearchString(debuggableSearchText)
        guard !query.isEmpty else { return debuggableSortedApps }
        return debuggableSortedApps.filter { matches(query, bundleID: $0.key, name: $0.value) }
    }

    private var filteredDebuggableSet: Set<String> {
        Set(filteredDebuggableApps.map { $0.key })
    }

    private var filteredFavoriteBundles: [String] {
        favoriteApps.filter { filteredDebuggableSet.contains($0) }
    }

    private var filteredRecentBundles: [String] {
        recentApps.filter { filteredDebuggableSet.contains($0) && !favoriteApps.contains($0) }
    }

    // NEW: Combined Launch tab (System + Other/Non-Debuggable)
    private var combinedLaunchApps: [String: String] {
        // Prefer names from systemApps when duplicates exist
        var combined = viewModel.nonDebuggableApps
        for (k, v) in viewModel.systemApps {
            combined[k] = v
        }
        return combined
    }

    private var sortedLaunchApps: [(key: String, value: String)] {
        combinedLaunchApps.sorted { lhs, rhs in
            let comparison = lhs.value.localizedCaseInsensitiveCompare(rhs.value)
            if comparison == .orderedSame {
                return lhs.key < rhs.key
            }
            return comparison == .orderedAscending
        }
    }

    private var launchSearchIsActive: Bool {
        !launchSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredLaunchApps: [(key: String, value: String)] {
        let base = sortedLaunchApps
        guard launchSearchIsActive else { return base }
        let query = normalizedSearchString(launchSearchText)
        guard !query.isEmpty else { return base }
        return base.filter { matches(query, bundleID: $0.key, name: $0.value) }
    }

private enum AppListTab: Int, CaseIterable, Identifiable {
    case debuggable
    case launch

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .debuggable: return "JIT"
        case .launch: return "Other"
        }
    }
}

    private struct LaunchFeedback: Identifiable {
        let id = UUID()
        let message: String
        let success: Bool
    }

    private func normalizedSearchString(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private func matches(_ normalizedQuery: String, bundleID: String, name: String) -> Bool {
        guard !normalizedQuery.isEmpty else { return true }
        let identifier = normalizedSearchString(bundleID)
        let displayName = normalizedSearchString(name)
        return identifier.contains(normalizedQuery) || displayName.contains(normalizedQuery)
    }

    private func isEmpty(for tab: AppListTab) -> Bool {
        switch tab {
        case .debuggable:
            return viewModel.debuggableApps.isEmpty
        case .launch:
            return filteredLaunchApps.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            tabContent(for: selectedTab)
                .transition(.opacity)
                .transaction { t in t.disablesAnimations = true }
                .navigationTitle(selectedTab == .debuggable ? "Enable JIT".localized : "Launch Apps".localized)
                .searchable(
                    text: currentSearchBinding,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: selectedTab == .debuggable
                        ? "Search apps or bundle ID".localized
                        : "Search".localized
                )
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("", selection: $selectedTab) {
                            ForEach(AppListTab.allCases) { tab in
                                Text(tab.title.localized).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                    if let onImportPairingFile {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: onImportPairingFile) {
                                Image(systemName: "doc.badge.plus")
                            }
                        }
                    }
                    if showDoneButton {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { dismiss() }.fontWeight(.semibold)
                        }
                    } else {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                viewModel.refreshAppLists()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                }
                .onAppear {
                }
        }
        .overlay {
            if let feedback = launchFeedback {
                VStack {
                    Spacer()
                    Text(feedback.message)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .foregroundStyle(feedback.success ? .green : .red)
                        .shadow(radius: 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 40)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: launchFeedback?.id)
            }
        }
                .onAppear {
            prefetchedBundleIDs.removeAll()
            prefetchPriorityIcons()
        }
        .onChange(of: favoriteApps) { _, _ in prefetchPriorityIcons() }
        .onChange(of: recentApps) { _, _ in prefetchPriorityIcons() }
        .onChange(of: viewModel.isLoading) { _, newValue in
            if newValue {
                prefetchedBundleIDs.removeAll()
            } else {
                prefetchPriorityIcons()
                // Ensure names for existing favorites are persisted once app list is ready
                persistIfChanged()
            }
        }
        .onChange(of: selectedTab) { _, _ in prefetchPriorityIcons() }
        .onChange(of: pinnedSystemApps) { _, _ in prefetchPriorityIcons() }
        .onReceive(NotificationCenter.default.publisher(for: .pairingFileImported)) { _ in
            viewModel.refreshAppLists()
        }
    }

    // MARK: Apps List

    private func prefetchPriorityIcons(limit: Int = 32) {
        guard loadAppIconsOnJIT else { return }

        var priorityIDs: [String] = []
        var seen = Set<String>()

        func appendUnique<S: Sequence>(_ ids: S) where S.Element == String {
            guard priorityIDs.count < limit else { return }
            for id in ids {
                guard seen.insert(id).inserted else { continue }
                priorityIDs.append(id)
                if priorityIDs.count >= limit { break }
            }
        }

        appendUnique(favoriteApps)
        appendUnique(recentApps)
        appendUnique(pinnedSystemApps)
        appendUnique(debuggableSortedApps.map { $0.key })
        appendUnique(sortedLaunchApps.map { $0.key })

        let toPrefetch = priorityIDs.filter { !prefetchedBundleIDs.contains($0) }
        guard !toPrefetch.isEmpty else { return }

        prefetchedBundleIDs.formUnion(toPrefetch)
        AppIconRepository.prefetch(bundleIDs: toPrefetch)
    }

    @ViewBuilder
    private func tabContent(for tab: AppListTab) -> some View {
        switch tab {
        case .debuggable:
            List {
                if let error = viewModel.lastError {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(.orange)
                    }
                }
                if filteredDebuggableApps.isEmpty && !viewModel.isLoading {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: debuggableSearchIsActive ? "text.magnifyingglass" : "magnifyingglass")
                                .font(.system(size: 36)).foregroundStyle(.secondary)
                            Text(debuggableSearchIsActive ? "No matching apps".localized : "No JIT Apps Found".localized)
                                .font(.headline)
                            Text(debuggableSearchIsActive
                                 ? "Try a different name or bundle identifier.".localized
                                 : "StikDebug can only connect to apps with the \"get-task-allow\" entitlement.".localized)
                                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    if !filteredFavoriteBundles.isEmpty {
                        Section(String(format: "Favorites (%d/4)".localized, filteredFavoriteBundles.count)) {
                            ForEach(filteredFavoriteBundles, id: \.self) { bundleID in
                                AppButton(
                                    bundleID: bundleID,
                                    appName: viewModel.debuggableApps[bundleID] ?? fallbackReadableName(from: bundleID),
                                    recentApps: $recentApps, favoriteApps: $favoriteApps,
                                    onSelectApp: onSelectApp, sharedDefaults: sharedDefaults, performanceMode: performanceMode
                                )
                            }
                        }
                    }
                    if !filteredRecentBundles.isEmpty {
                        Section("Recents".localized) {
                            ForEach(filteredRecentBundles, id: \.self) { bundleID in
                                AppButton(
                                    bundleID: bundleID,
                                    appName: viewModel.debuggableApps[bundleID] ?? fallbackReadableName(from: bundleID),
                                    recentApps: $recentApps, favoriteApps: $favoriteApps,
                                    onSelectApp: onSelectApp, sharedDefaults: sharedDefaults, performanceMode: performanceMode
                                )
                            }
                        }
                    }
                    Section("Apps with get-task-allow".localized) {
                        ForEach(filteredDebuggableApps, id: \.key) { bundleID, appName in
                            AppButton(
                                bundleID: bundleID, appName: appName,
                                recentApps: $recentApps, favoriteApps: $favoriteApps,
                                onSelectApp: onSelectApp, sharedDefaults: sharedDefaults, performanceMode: performanceMode
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

        case .launch:
            List {
                if let error = viewModel.lastError {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(.orange)
                    }
                }
                if filteredLaunchApps.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36)).foregroundStyle(.secondary)
                            Text(launchSearchIsActive ? "No matches".localized : "No Apps Found".localized)
                                .font(.headline)
                            Text(launchSearchIsActive
                                 ? "Try another name or bundle identifier.".localized
                                 : "Once your device pairing file is imported and CoreDevice is connected, all apps will appear here.".localized)
                                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("All Apps".localized) {
                        ForEach(filteredLaunchApps, id: \.key) { bundleID, appName in
                            let isPinned = pinnedSystemApps.contains(bundleID)
                            LaunchAppRow(
                                bundleID: bundleID, appName: appName,
                                isLaunching: launchingBundles.contains(bundleID),
                                performanceMode: performanceMode
                            ) { startLaunching(bundleID: bundleID) }
                            .overlay(alignment: .topTrailing) {
                                if isPinned {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.yellow).padding(6)
                                }
                            }
                            .contextMenu {
                                Button((isPinned ? "Remove from Home" : "Add to Home").localized,
                                       systemImage: isPinned ? "star.slash" : "star") {
                                    toggleSystemPin(bundleID: bundleID, appName: appName)
                                }
                                Button("Copy Bundle ID".localized, systemImage: "doc.on.doc") {
                                    UIPasteboard.general.string = bundleID
                                    Haptics.light()
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    toggleSystemPin(bundleID: bundleID, appName: appName)
                                } label: {
                                    Label((isPinned ? "Unpin" : "Pin").localized, systemImage: "star")
                                }
                                .tint(.yellow)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: Persistence gate (avoid redundant writes + reloads)

    private func persistIfChanged() {
        var touched = false
        let prevR = (sharedDefaults.array(forKey: "recentApps") as? [String]) ?? []
        let prevF = (sharedDefaults.array(forKey: "favoriteApps") as? [String]) ?? []
        let prevPinned = (sharedDefaults.array(forKey: "pinnedSystemApps") as? [String]) ?? []
        let prevPinnedNames = (sharedDefaults.dictionary(forKey: "pinnedSystemAppNames") as? [String: String]) ?? [:]
        let prevFavNames = (sharedDefaults.dictionary(forKey: ScriptStore.favoriteAppNamesKey) as? [String: String]) ?? [:]

        if prevR != recentApps {
            sharedDefaults.set(recentApps, forKey: "recentApps")
            touched = true
        }
        if prevF != favoriteApps {
            sharedDefaults.set(favoriteApps, forKey: "favoriteApps")
            touched = true
        }
        if prevPinned != pinnedSystemApps {
            sharedDefaults.set(pinnedSystemApps, forKey: "pinnedSystemApps")
            touched = true
        }
        if prevPinnedNames != pinnedSystemAppNames {
            sharedDefaults.set(pinnedSystemAppNames, forKey: "pinnedSystemAppNames")
            touched = true
        }

        // Persist favorite names for the widget (prefer actual names from lists)
        let computedFavNames: [String: String] = Dictionary(uniqueKeysWithValues: favoriteApps.map { id in
            let name = viewModel.debuggableApps[id]
                ?? combinedLaunchApps[id]
                ?? fallbackReadableName(from: id)
            return (id, name)
        })
        if prevFavNames != computedFavNames {
            sharedDefaults.set(computedFavNames, forKey: ScriptStore.favoriteAppNamesKey)
            touched = true
        }

        if touched { WidgetCenter.shared.reloadAllTimelines() }
    }

    private func startLaunching(bundleID: String) {
        guard !launchingBundles.contains(bundleID) else { return }
        launchingBundles.insert(bundleID)
        Haptics.selection()

        viewModel.launchWithoutDebug(bundleID: bundleID) { success in
            launchingBundles.remove(bundleID)

            let message = success ? "Launch request sent".localized : "Launch failed".localized
            let feedback = LaunchFeedback(message: message, success: success)

            if success {
                Haptics.light()
            }

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

    // Pin/unpin any launchable app (not just hidden system)
    private func toggleSystemPin(bundleID: String, appName: String) {
        Haptics.light()
        if let index = pinnedSystemApps.firstIndex(of: bundleID) {
            pinnedSystemApps.remove(at: index)
            pinnedSystemAppNames.removeValue(forKey: bundleID)
        } else {
            pinnedSystemApps.removeAll { $0 == bundleID }
            pinnedSystemApps.insert(bundleID, at: 0)
            pinnedSystemAppNames[bundleID] = appName
            let maxPins = 8
            if pinnedSystemApps.count > maxPins {
                let surplus = Array(pinnedSystemApps.suffix(from: maxPins))
                for id in surplus { pinnedSystemAppNames.removeValue(forKey: id) }
                pinnedSystemApps = Array(pinnedSystemApps.prefix(maxPins))
            }
        }
        persistIfChanged()
    }

    // Fallback readable name from bundle identifier
    private func fallbackReadableName(from bundleID: String) -> String {
        let components = bundleID.split(separator: ".")
        if let last = components.last {
            let cleaned = last.replacingOccurrences(of: "_", with: " ")
            let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed.capitalized }
        }
        return bundleID
    }
}

// MARK: - App Button Row

struct AppButton: View {
    let bundleID: String
    let appName: String

    @Binding var recentApps: [String]
    @Binding var favoriteApps: [String]

    @AppStorage("loadAppIconsOnJIT") private var loadAppIconsOnJIT = true
    @AppStorage("enableAdvancedOptions") private var enableAdvancedOptions = false

    var onSelectApp: (String) -> Void
    let sharedDefaults: UserDefaults
    let performanceMode: Bool

    @State private var showScriptPicker = false
    @State private var assignedScriptName: String?
    @StateObject private var iconLoader: IconLoader

    init(
        bundleID: String,
        appName: String,
        recentApps: Binding<[String]>,
        favoriteApps: Binding<[String]>,
        onSelectApp: @escaping (String) -> Void,
        sharedDefaults: UserDefaults,
        performanceMode: Bool
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self._recentApps = recentApps
        self._favoriteApps = favoriteApps
        self.onSelectApp = onSelectApp
        self.sharedDefaults = sharedDefaults
        self.performanceMode = performanceMode
        _iconLoader = StateObject(wrappedValue: IconLoader(bundleID: bundleID))
        _assignedScriptName = State(initialValue: AppButton.currentAssignment(for: bundleID))
    }

    var body: some View {
        Button(action: selectApp) {
            HStack(spacing: loadAppIconsOnJIT ? 16 : 12) {
                iconView

                VStack(alignment: .leading, spacing: 3) {
                    Text(appName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(bundleID)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }

                Spacer()

                if favoriteApps.contains(bundleID) {
                    Image(systemName: "star.fill")
                        .imageScale(.medium)
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, loadAppIconsOnJIT ? 4 : 8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: toggleFavorite) {
                Label(
                    favoriteApps.contains(bundleID) ? "Remove Favorite" : "Add to Favorites",
                    systemImage: favoriteApps.contains(bundleID) ? "star.slash" : "star"
                )
                .disabled(!favoriteApps.contains(bundleID) && favoriteApps.count >= 4)
            }
            Button {
                UIPasteboard.general.string = bundleID
                Haptics.light()
            } label: {
                Label("Copy Bundle ID", systemImage: "doc.on.doc")
            }
            if enableAdvancedOptions {
                Button { showScriptPicker = true } label: {
                    Label("Assign Script", systemImage: "chevron.left.slash.chevron.right")
                }
                if assignedScriptName != nil {
                    Button {
                        resetScriptAssignment()
                    } label: {
                        Label("Reset Script", systemImage: "arrow.uturn.left")
                    }
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                toggleFavorite()
            } label: {
                Label(favoriteApps.contains(bundleID) ? "Unfavorite" : "Favorite", systemImage: "star")
            }
            .tint(.yellow)

            Button {
                UIPasteboard.general.string = bundleID
                Haptics.light()
            } label: {
                Label("Copy ID", systemImage: "doc.on.doc")
            }
        }
        .sheet(isPresented: $showScriptPicker) {
            ScriptListView { url in
                assignScript(url)
                showScriptPicker = false
            }
        }
        .onAppear {
            if loadAppIconsOnJIT {
                iconLoader.beginLoading()
            }
        }
        .onChange(of: loadAppIconsOnJIT) { _, newValue in
            if newValue {
                iconLoader.beginLoading()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appName)")
        .accessibilityHint("Double-tap to select. Swipe for actions, long-press for options.")
    }

    // MARK: Icon

    private var iconView: some View {
        Group {
            if loadAppIconsOnJIT, let image = iconLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1.5)
                    .transition(.opacity.combined(with: .scale))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "app")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(.gray)
                    )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func selectApp() {
        Haptics.selection()
        recentApps.removeAll { $0 == bundleID }
        recentApps.insert(bundleID, at: 0)
        if recentApps.count > 3 {
            recentApps = Array(recentApps.prefix(3))
        }
        persistIfChanged()
        onSelectApp(bundleID)
    }

    private func toggleFavorite() {
        Haptics.light()
        if favoriteApps.contains(bundleID) {
            favoriteApps.removeAll { $0 == bundleID }
        } else if favoriteApps.count < 4 {
            favoriteApps.insert(bundleID, at: 0)
            recentApps.removeAll { $0 == bundleID }
        }
        persistIfChanged()
    }

    private func assignScript(_ url: URL?) {
        if let url {
            let filename = url.lastPathComponent
            ScriptStore.updateAssignedScriptName(filename, for: bundleID)
            assignedScriptName = filename
        } else {
            ScriptStore.updateAssignedScriptName(nil, for: bundleID)
            assignedScriptName = nil
        }
        Haptics.light()
    }

    private func resetScriptAssignment() {
        assignScript(nil)
    }

    private static func currentAssignment(for bundleID: String) -> String? {
        ScriptStore.assignedScriptName(for: bundleID)
    }

    private func persistIfChanged() {
        var touched = false
        let prevR = (sharedDefaults.array(forKey: "recentApps") as? [String]) ?? []
        let prevF = (sharedDefaults.array(forKey: "favoriteApps") as? [String]) ?? []

        if prevR != recentApps {
            sharedDefaults.set(recentApps, forKey: "recentApps")
            touched = true
        }
        if prevF != favoriteApps {
            sharedDefaults.set(favoriteApps, forKey: "favoriteApps")
            touched = true
        }
        if touched { WidgetCenter.shared.reloadAllTimelines() }
    }
}

// MARK: - Launch Row

struct LaunchAppRow: View {
    let bundleID: String
    let appName: String
    let isLaunching: Bool

    @AppStorage("loadAppIconsOnJIT") private var loadAppIconsOnJIT = true

    let performanceMode: Bool
    var launchAction: () -> Void

    @StateObject private var iconLoader: IconLoader

    init(
        bundleID: String,
        appName: String,
        isLaunching: Bool,
        performanceMode: Bool,
        launchAction: @escaping () -> Void
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self.isLaunching = isLaunching
        self.performanceMode = performanceMode
        self.launchAction = launchAction
        _iconLoader = StateObject(wrappedValue: IconLoader(bundleID: bundleID))
    }

    var body: some View {
        Button {
            guard !isLaunching else { return }
            launchAction()
        } label: {
            HStack(spacing: loadAppIconsOnJIT ? 16 : 12) {
                iconView

                VStack(alignment: .leading, spacing: 3) {
                    Text(appName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(bundleID)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }

                Spacer()

                if isLaunching {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Launch".localized)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, loadAppIconsOnJIT ? 4 : 8)
        }
        .buttonStyle(.plain)
        .disabled(isLaunching)
        .onAppear {
            if loadAppIconsOnJIT {
                iconLoader.beginLoading()
            }
        }
        .onChange(of: loadAppIconsOnJIT) { _, newValue in
            if newValue {
                iconLoader.beginLoading()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appName)")
        .accessibilityHint("Double-tap to launch via CoreDevice.")
    }

    private var iconView: some View {
        Group {
            if loadAppIconsOnJIT, let image = iconLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1.5)
                    .transition(.opacity.combined(with: .scale))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "app")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(.gray)
                    )
            }
        }
        .accessibilityHidden(true)
    }

}

private actor IconFetchRegistry {
    private var tasks: [String: Task<UIImage?, Never>] = [:]

    func task(for bundleID: String, create: () -> Task<UIImage?, Never>) -> Task<UIImage?, Never> {
        if let existing = tasks[bundleID] {
            return existing
        }
        let task = create()
        tasks[bundleID] = task
        return task
    }

    func clear(bundleID: String) {
        tasks[bundleID] = nil
    }
}

private actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(permits: Int) {
        self.permits = permits
    }

    func acquire() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            permits += 1
        }
    }
}

enum AppIconRepository {
    private static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 2000
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    private static let diskQueue = DispatchQueue(label: "com.stik.iconcache.disk", qos: .utility)
    private static let fetchSemaphore = AsyncSemaphore(permits: 4)
    private static let registry = IconFetchRegistry()
    private static let appGroupIdentifier = "group.com.stik.sj"

    static func cachedImage(for bundleID: String) -> UIImage? {
        memory.object(forKey: bundleID as NSString)
    }

    static func image(for bundleID: String) async -> UIImage? {
        if let mem = cachedImage(for: bundleID) {
            return mem
        }

        if let disk = await loadFromDisk(bundleID: bundleID) {
            storeInMemory(disk, for: bundleID)
            return disk
        }

        return await fetchAndStore(bundleID: bundleID)
    }

    static func prefetch(bundleIDs: [String]) {
        let unique = Set(bundleIDs)
        for bundleID in unique {
            Task.detached(priority: .utility) {
                _ = await image(for: bundleID)
            }
        }
    }

    static func removeFromCache(bundleIDs: [String]) {
        guard !bundleIDs.isEmpty else { return }
        for id in bundleIDs {
            memory.removeObject(forKey: id as NSString)
        }
        diskQueue.async {
            for id in bundleIDs {
                guard let url = iconURL(for: id) else { continue }
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private static func fetchAndStore(bundleID: String) async -> UIImage? {
        let task = await registry.task(for: bundleID) {
            Task.detached(priority: .utility) {
                await fetchSemaphore.acquire()

                let result: UIImage?
                if let fetched = await fetchFromSource(bundleID: bundleID) {
                    let prepared = prepareForDisplay(fetched)
                    store(prepared, for: bundleID)
                    result = prepared
                } else {
                    result = nil
                }

                await fetchSemaphore.release()
                await registry.clear(bundleID: bundleID)
                return result
            }
        }
        return await task.value
    }

    private static func fetchFromSource(bundleID: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            AppStoreIconFetcher.getIcon(for: bundleID) { image in
                continuation.resume(returning: image)
            }
        }
    }

    private static func loadFromDisk(bundleID: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            diskQueue.async {
                guard let url = iconURL(for: bundleID),
                      FileManager.default.fileExists(atPath: url.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let data = try? Data(contentsOf: url) else {
                    try? FileManager.default.removeItem(at: url)
                    continuation.resume(returning: nil)
                    return
                }
                guard let image = UIImage(data: data, scale: UIScreen.main.scale) else {
                    try? FileManager.default.removeItem(at: url)
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: prepareForDisplay(image))
            }
        }
    }

    private static func store(_ image: UIImage, for bundleID: String) {
        storeInMemory(image, for: bundleID)
        storeOnDisk(image, bundleID: bundleID)
    }

    private static func storeInMemory(_ image: UIImage, for bundleID: String) {
        memory.setObject(image, forKey: bundleID as NSString, cost: memoryCost(for: image))
    }

    private static func storeOnDisk(_ image: UIImage, bundleID: String) {
        diskQueue.async {
            guard let url = iconURL(for: bundleID),
                  let data = image.pngData() else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                // Best-effort cache write.
            }
        }
    }

    private static func iconURL(for bundleID: String) -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        let directory = container.appendingPathComponent("icons", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return directory.appendingPathComponent("\(bundleID).png")
    }

    private static func memoryCost(for image: UIImage) -> Int {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        return max(width * height * 4, 1)
    }

    private static func prepareForDisplay(_ image: UIImage) -> UIImage {
        if #available(iOS 15.0, *) {
            return image.preparingForDisplay() ?? image
        }
        return image
    }
}

@MainActor
final class IconLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private let bundleID: String
    private var didStart = false

    init(bundleID: String) {
        self.bundleID = bundleID
        if let cached = AppIconRepository.cachedImage(for: bundleID) {
            image = cached
            didStart = true
        }
    }

    func beginLoading() {
        if image != nil {
            didStart = true
            return
        }
        guard !didStart else { return }
        didStart = true

        let targetID = bundleID
        Task { [weak self] in
            if let resolved = await AppIconRepository.image(for: targetID) {
                guard let self else { return }
                withAnimation(.linear(duration: 0.12)) {
                    self.image = resolved
                }
            } else {
                self?.didStart = false
            }
        }
    }
}

enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Utilities

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}

extension Dictionary: @retroactive RawRepresentable where Key: Codable, Value: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Key: Value].self, from: data)
        else { return nil }
        self = result
    }
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else { return "{}" }
        return result
    }
}

// MARK: - Preview

struct InstalledAppsListView_Previews: PreviewProvider {
    static var previews: some View {
        InstalledAppsListView { _ in }
            .environment(\.colorScheme, .dark)
    }
}


class InstalledAppsViewModel: ObservableObject {
    @Published var debuggableApps: [String: String] = [:]
    @Published var nonDebuggableApps: [String: String] = [:]
    @Published var systemApps: [String: String] = [:]
    @Published var isLoading = false
    @Published var lastError: String? = nil

    private let workQueue = DispatchQueue(label: "com.stik.installedApps", qos: .userInitiated)
    private let cache = UserDefaults(suiteName: "group.com.stik.sj") ?? .standard
    private let cacheKeyDebuggable = "cachedDebuggableApps"
    private let cacheKeyNonDebuggable = "cachedNonDebuggableApps"
    private let cacheKeySystem = "cachedSystemApps"

    init() {
        loadCachedApps()
        refreshAppLists()
    }

    func refreshAppLists() {
        isLoading = true
        lastError = nil

        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                let debuggable = try JITEnableContext.shared.getAppList()
                let allApps = try JITEnableContext.shared.getAllApps()
                let hiddenSystem = (try? JITEnableContext.shared.getHiddenSystemApps()) ?? [:]

                let nonDebuggableSequence = allApps.filter { debuggable[$0.key] == nil }
                var nonDebuggable: [String: String] = [:]
                var system: [String: String] = [:]

                for (bundle, name) in nonDebuggableSequence {
                    if let hiddenName = hiddenSystem[bundle] {
                        system[bundle] = hiddenName
                    } else {
                        nonDebuggable[bundle] = name
                    }
                }

                for (bundle, name) in hiddenSystem where system[bundle] == nil && debuggable[bundle] == nil {
                    system[bundle] = name
                }

                DispatchQueue.main.async {
                    self.debuggableApps = debuggable
                    self.nonDebuggableApps = nonDebuggable
                    self.systemApps = system
                    self.isLoading = false
                    self.cacheApps(debuggable: debuggable, nonDebuggable: nonDebuggable, system: system)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func loadCachedApps() {
        func decode(_ key: String) -> [String: String] {
            guard let data = cache.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
            return decoded
        }

        let cachedDebuggable = decode(cacheKeyDebuggable)
        let cachedNonDebuggable = decode(cacheKeyNonDebuggable)
        let cachedSystem = decode(cacheKeySystem)

        if !cachedDebuggable.isEmpty || !cachedNonDebuggable.isEmpty || !cachedSystem.isEmpty {
            debuggableApps = cachedDebuggable
            nonDebuggableApps = cachedNonDebuggable
            systemApps = cachedSystem
        }
    }

    private func cacheApps(debuggable: [String: String], nonDebuggable: [String: String], system: [String: String]) {
        func encode(_ value: [String: String]) -> Data? {
            try? JSONEncoder().encode(value)
        }

        cache.set(encode(debuggable), forKey: cacheKeyDebuggable)
        cache.set(encode(nonDebuggable), forKey: cacheKeyNonDebuggable)
        cache.set(encode(system), forKey: cacheKeySystem)
    }

    func launchWithoutDebug(bundleID: String, completion: @escaping (Bool) -> Void) {
        workQueue.async {
            let success = JITEnableContext.shared.launchAppWithoutDebug(bundleID, logger: nil)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
