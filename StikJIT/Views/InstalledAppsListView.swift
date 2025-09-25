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

    @State private var appIcons: [String: UIImage] = [:]
    private let sharedDefaults = UserDefaults(suiteName: "group.com.stik.sj")!

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
    @AppStorage("performanceMode") private var performanceMode = false
    @State private var showPerformanceToast = false
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

    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.themeExpansionManager) private var themeExpansion
    private var backgroundStyle: BackgroundStyle { themeExpansion?.backgroundStyle(for: appThemeRaw) ?? AppTheme.system.backgroundStyle }
    private var preferredScheme: ColorScheme? { themeExpansion?.preferredColorScheme(for: appThemeRaw) }

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

    private enum AppListTab: String, CaseIterable, Identifiable {
        case debuggable
        case launch

        var id: String { rawValue }

        var title: String {
            switch self {
            case .debuggable: return "Debuggable"
            case .launch: return "Launch"
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
            ZStack {
                ThemedBackground(style: backgroundStyle)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading Apps…".localized)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    tabbedContent
                        .transition(.opacity)
                        .transaction { t in t.disablesAnimations = true }
                }

                if showPerformanceToast {
                    VStack {
                        Spacer()
                        Text(performanceMode ? "Performance Mode On" : "Performance Mode Off")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(radius: 4)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 40)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPerformanceToast)
                }

                if let feedback = launchFeedback {
                    VStack {
                        Spacer()
                        Text(feedback.message)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(feedback.success ? Color.green.opacity(0.35) : Color.red.opacity(0.35), lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(feedback.success ? .green : .red)
                            .shadow(radius: 4)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 40)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: launchFeedback?.id)
                }
            }
            .navigationTitle("Installed Apps".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        performanceMode.toggle()
                        Haptics.selection()
                        showPerformanceToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                showPerformanceToast = false
                            }
                        }
                    } label: {
                        Image(systemName: performanceMode ? "bolt.fill" : "bolt.slash.fill")
                            .imageScale(.large)
                            .foregroundStyle(performanceMode ? .yellow : .secondary)
                            .accessibilityLabel("Toggle Performance Mode")
                            .accessibilityValue(performanceMode ? "On" : "Off")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(preferredScheme)
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
    }

    // MARK: Empty State

    private func emptyState(for tab: AppListTab) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(.secondary)

            switch tab {
            case .debuggable:
                Text("No Debuggable App Found".localized)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("""
                StikDebug can only connect to apps with the “get-task-allow” entitlement.
                Please check if the app you want to connect to is signed with a development certificate.
                """.localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            case .launch:
                Text("No Launchable Apps".localized)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("""
                Once your device pairing file is imported and CoreDevice is connected, all non‑debuggable and hidden system apps will appear here.
                """.localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
        }
        .padding(24)
        .glassCard(cornerRadius: 24, material: .thinMaterial, strokeOpacity: 0.12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tab == .debuggable ? "No debuggable apps available" : "No launchable apps available")
    }

    // MARK: Apps List

    private func debuggableSections(
        apps: [(key: String, value: String)],
        favorites: [String],
        recents: [String]
    ) -> some View {
        VStack(spacing: 18) {
            if !favorites.isEmpty {
                glassSection(
                    title: String(format: "Favorites (%d/4)".localized, favorites.count)
                ) {
                    LazyVStack(spacing: 12) {
                        ForEach(favorites, id: \.self) { bundleID in
                            AppButton(
                                bundleID: bundleID,
                                appName: viewModel.debuggableApps[bundleID] ?? bundleID,
                                recentApps: $recentApps,
                                favoriteApps: $favoriteApps,
                                appIcons: $appIcons,
                                onSelectApp: onSelectApp,
                                sharedDefaults: sharedDefaults,
                                performanceMode: performanceMode
                            )
                        }
                    }
                }
            }

            if !recents.isEmpty {
                glassSection(title: "Recents".localized) {
                    LazyVStack(spacing: 12) {
                        ForEach(recents, id: \.self) { bundleID in
                            AppButton(
                                bundleID: bundleID,
                                appName: viewModel.debuggableApps[bundleID] ?? bundleID,
                                recentApps: $recentApps,
                                favoriteApps: $favoriteApps,
                                appIcons: $appIcons,
                                onSelectApp: onSelectApp,
                                sharedDefaults: sharedDefaults,
                                performanceMode: performanceMode
                            )
                        }
                    }
                }
            }

            glassSection(title: "All Applications".localized) {
                LazyVStack(spacing: 12) {
                    ForEach(apps, id: \.key) { bundleID, appName in
                        AppButton(
                            bundleID: bundleID,
                            appName: appName,
                            recentApps: $recentApps,
                            favoriteApps: $favoriteApps,
                            appIcons: $appIcons,
                            onSelectApp: onSelectApp,
                            sharedDefaults: sharedDefaults,
                            performanceMode: performanceMode
                        )
                    }
                }
            }
        }
    }

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
        IconCache.shared.prefetchIcons(for: toPrefetch)
    }

    private func launchSections(apps: [(key: String, value: String)]) -> some View {
        glassSection(title: "Launchable Apps".localized) {
            LazyVStack(spacing: 12) {
                ForEach(apps, id: \.key) { bundleID, appName in
                    let isPinned = pinnedSystemApps.contains(bundleID)
                    LaunchAppRow(
                        bundleID: bundleID,
                        appName: appName,
                        isLaunching: launchingBundles.contains(bundleID),
                        appIcons: $appIcons,
                        performanceMode: performanceMode
                    ) {
                        startLaunching(bundleID: bundleID)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isPinned {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.yellow)
                                .padding(6)
                        }
                    }
                    .contextMenu {
                        Button((isPinned ? "Remove from Home" : "Add to Home").localized, systemImage: isPinned ? "star.slash" : "star") {
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

    @ViewBuilder
    private var tabbedContent: some View {
        VStack(spacing: 14) {
            Picker("", selection: $selectedTab) {
                ForEach(AppListTab.allCases) { tab in
                    Text(tab.title.localized)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            tabContent(for: selectedTab)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppListTab) -> some View {
        switch tab {
        case .debuggable:
            if viewModel.debuggableApps.isEmpty {
                VStack {
                    Spacer(minLength: 0)
                    emptyState(for: .debuggable)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .transition(.opacity.combined(with: .scale))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        debuggableSearchBar

                        if let error = viewModel.lastError {
                            errorBanner(error)
                        }

                        if filteredDebuggableApps.isEmpty {
                            debuggableSearchEmptyState
                                .transition(.opacity.combined(with: .scale))
                        } else {
                            debuggableSections(
                                apps: filteredDebuggableApps,
                                favorites: filteredFavoriteBundles,
                                recents: filteredRecentBundles
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
        case .launch:
            ScrollView {
                VStack(spacing: 18) {
                    launchSearchBar

                    if let error = viewModel.lastError {
                        errorBanner(error)
                    }

                    if filteredLaunchApps.isEmpty {
                        if launchSearchIsActive {
                            launchSearchEmptyState
                                .transition(.opacity.combined(with: .scale))
                        } else {
                            emptyState(for: .launch)
                                .transition(.opacity.combined(with: .scale))
                        }
                    } else {
                        launchSections(apps: filteredLaunchApps)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
    }

    private var debuggableSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search apps or bundle ID".localized, text: $debuggableSearchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            if debuggableSearchIsActive {
                Button {
                    debuggableSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search".localized)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var debuggableSearchEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)

            Text("No matching apps".localized)
                .font(.title3.weight(.semibold))

            Text("Try a different name or bundle identifier.".localized)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .glassCard(cornerRadius: 20, material: .thinMaterial, strokeOpacity: 0.12)
    }

    private var launchSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search".localized, text: $launchSearchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            if launchSearchIsActive {
                Button {
                    launchSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search".localized)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var launchSearchEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)

            Text("No matches".localized)
                .font(.title3.weight(.semibold))

            Text("Try another name or bundle identifier.".localized)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .glassCard(cornerRadius: 20, material: .thinMaterial, strokeOpacity: 0.12)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            )
    }

    // MARK: Section Wrapper

    private func glassSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            content()
        }
        .padding(20)
        .glassCard(material: .thinMaterial, strokeOpacity: 0.12)
    }

    // MARK: Persistence gate (avoid redundant writes + reloads)

    private func persistIfChanged() {
        var touched = false
        let prevR = (sharedDefaults.array(forKey: "recentApps") as? [String]) ?? []
        let prevF = (sharedDefaults.array(forKey: "favoriteApps") as? [String]) ?? []
        let prevPinned = (sharedDefaults.array(forKey: "pinnedSystemApps") as? [String]) ?? []
        let prevPinnedNames = (sharedDefaults.dictionary(forKey: "pinnedSystemAppNames") as? [String: String]) ?? [:]
        let prevFavNames = (sharedDefaults.dictionary(forKey: "favoriteAppNames") as? [String: String]) ?? [:]

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
            sharedDefaults.set(computedFavNames, forKey: "favoriteAppNames")
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
    @Binding var appIcons: [String: UIImage]

    @AppStorage("loadAppIconsOnJIT") private var loadAppIconsOnJIT = true
    @AppStorage("enableAdvancedOptions") private var enableAdvancedOptions = false
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.themeExpansionManager) private var themeExpansion

    var onSelectApp: (String) -> Void
    let sharedDefaults: UserDefaults
    let performanceMode: Bool

    @State private var showScriptPicker = false

    private var rowBackgroundStyle: BackgroundStyle { themeExpansion?.backgroundStyle(for: appThemeRaw) ?? AppTheme.system.backgroundStyle }

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
            .padding(.vertical, loadAppIconsOnJIT ? 8 : 12)
            .padding(.horizontal, 12)
            .background(rowBackground)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                loadAppIcon(for: bundleID)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appName)")
        .accessibilityHint("Double-tap to select. Swipe for actions, long-press for options.")
    }

    // MARK: Icon

    private var iconView: some View {
        Group {
            if loadAppIconsOnJIT, let image = appIcons[bundleID] {
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

    // MARK: Row Background

    private var rowBackground: some View {
        ThemedRowBackground(performanceMode: performanceMode, style: rowBackgroundStyle, cornerRadius: 16)
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
        var mapping = UserDefaults.standard.dictionary(forKey: "BundleScriptMap") as? [String: String] ?? [:]
        if let url {
            mapping[bundleID] = url.lastPathComponent
        } else {
            mapping.removeValue(forKey: bundleID)
        }
        UserDefaults.standard.set(mapping, forKey: "BundleScriptMap")
        Haptics.light()
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

    private func loadAppIcon(for bundleID: String) {
        guard loadAppIconsOnJIT else { return }
        guard appIcons[bundleID] == nil else { return }
        IconCache.shared.fetchIcon(for: bundleID, priority: .veryHigh) { image in
            guard let image else { return }
            let shouldAnimate = appIcons[bundleID] == nil
            if shouldAnimate {
                withAnimation(.linear(duration: 0.12)) {
                    appIcons[bundleID] = image
                }
            } else {
                appIcons[bundleID] = image
            }
        }
    }
}

// MARK: - IconCache

struct LaunchAppRow: View {
    let bundleID: String
    let appName: String
    let isLaunching: Bool

    @Binding var appIcons: [String: UIImage]

    @AppStorage("loadAppIconsOnJIT") private var loadAppIconsOnJIT = true
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.themeExpansionManager) private var themeExpansion

    let performanceMode: Bool
    var launchAction: () -> Void

    private var rowBackgroundStyle: BackgroundStyle { themeExpansion?.backgroundStyle(for: appThemeRaw) ?? AppTheme.system.backgroundStyle }

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
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Launch".localized)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.18))
                        )
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, loadAppIconsOnJIT ? 8 : 12)
            .padding(.horizontal, 12)
            .background(rowBackground)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLaunching)
        .onAppear {
            if loadAppIconsOnJIT {
                loadAppIcon(for: bundleID)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appName)")
        .accessibilityHint("Double-tap to launch via CoreDevice.")
    }

    private var iconView: some View {
        Group {
            if loadAppIconsOnJIT, let image = appIcons[bundleID] {
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

    private var rowBackground: some View {
        ThemedRowBackground(performanceMode: performanceMode, style: rowBackgroundStyle, cornerRadius: 16)
    }

    private func loadAppIcon(for bundleID: String) {
        guard loadAppIconsOnJIT else { return }
        guard appIcons[bundleID] == nil else { return }
        IconCache.shared.fetchIcon(for: bundleID, priority: .veryHigh) { image in
            guard let image else { return }
            let shouldAnimate = appIcons[bundleID] == nil
            if shouldAnimate {
                withAnimation(.linear(duration: 0.12)) {
                    appIcons[bundleID] = image
                }
            } else {
                appIcons[bundleID] = image
            }
        }
    }
}

private struct ThemedRowBackground: View {
    var performanceMode: Bool
    var style: BackgroundStyle
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return Group {
            if performanceMode {
                shape
                    .fill(Color(.secondarySystemBackground).opacity(0.65))
                    .overlay(shape.stroke(Color.white.opacity(0.10), lineWidth: 1))
            } else {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    themedOverlay(shape: shape)
                    shape.stroke(Color.white.opacity(0.15), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            }
        }
    }

    @ViewBuilder
    private func themedOverlay(shape: RoundedRectangle) -> some View {
        switch style {
        case .staticGradient(let colors), .customGradient(let colors):
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: normalized(colors)),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.32)
        case .animatedGradient(let colors, _):
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: normalized(colors)),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(0.38)
        case .blobs(let colors, _):
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: normalized(colors)),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(0.40)
        case .particles(let particle, _):
            shape.fill(particle.opacity(0.18))
        case .adaptiveGradient(let light, let dark):
            let palette = colorScheme == .dark ? dark : light
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: normalized(palette)),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.32)
        }
    }

    private func normalized(_ colors: [Color]) -> [Color] {
        if colors.count >= 2 { return colors }
        if let first = colors.first { return [first, first.opacity(0.6)] }
        return [Color.blue, Color.purple]
    }
}

final class IconCache {
    static let shared = IconCache()

    private let mem = NSCache<NSString, UIImage>()
    private let queue = OperationQueue()
    private let callbackQueue = DispatchQueue(label: "com.stik.iconcache.callbacks")
    private var pendingCallbacks: [String: [(UIImage?) -> Void]] = [:]
    private var pendingOperations: [String: Operation] = [:]

    private init() {
        queue.maxConcurrentOperationCount = 4
        queue.qualityOfService = .userInitiated
        mem.countLimit = 1000
        mem.totalCostLimit = 64 * 1024 * 1024
    }

    func fetchIcon(
        for bundleID: String,
        priority: Operation.QueuePriority = .normal,
        completion: @escaping (UIImage?) -> Void
    ) {
        if let memImage = mem.object(forKey: bundleID as NSString) {
            DispatchQueue.main.async { completion(memImage) }
            return
        }

        var shouldStartLoad = false
        callbackQueue.sync {
            if var existing = pendingCallbacks[bundleID] {
                existing.append(completion)
                pendingCallbacks[bundleID] = existing
                if let op = pendingOperations[bundleID], op.queuePriority.rawValue < priority.rawValue {
                    op.queuePriority = priority
                }
            } else {
                pendingCallbacks[bundleID] = [completion]
                shouldStartLoad = true
            }
        }

        guard shouldStartLoad else { return }

        let operation = BlockOperation { [weak self] in
            guard let self else { return }

            var loadedFromDisk = false
            var result = self.diskCachedIcon(for: bundleID)
            if result != nil {
                loadedFromDisk = true
            }

            if result == nil {
                let semaphore = DispatchSemaphore(value: 0)
                AppStoreIconFetcher.getIcon(for: bundleID) { image in
                    result = image
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 10)
            }

            if let image = result {
                let prepared = self.prepareForDisplay(image)
                let cost = Int(prepared.size.width * prepared.size.height * prepared.scale * prepared.scale)
                self.mem.setObject(prepared, forKey: bundleID as NSString, cost: cost)
                if !loadedFromDisk {
                    saveIconToGroup(prepared, bundleID: bundleID)
                }
                result = prepared
            }

            let callbacks = self.callbackQueue.sync { () -> [(UIImage?) -> Void] in
                let handlers = self.pendingCallbacks[bundleID] ?? []
                self.pendingCallbacks[bundleID] = nil
                self.pendingOperations[bundleID] = nil
                return handlers
            }

            DispatchQueue.main.async {
                callbacks.forEach { $0(result) }
            }
        }
        operation.queuePriority = priority

        callbackQueue.sync {
            pendingOperations[bundleID] = operation
        }

        queue.addOperation(operation)
    }

    func prefetchIcons(for bundleIDs: [String]) {
        let uniqueIDs = Set(bundleIDs)
        for bundleID in uniqueIDs {
            fetchIcon(for: bundleID, priority: .veryLow) { _ in }
        }
    }

    private func diskCachedIcon(for bundleID: String) -> UIImage? {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.stik.sj")
        else { return nil }

        let iconsDir = containerURL.appendingPathComponent("icons", isDirectory: true)
        let fileURL = iconsDir.appendingPathComponent("\(bundleID).png")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        guard let data = try? Data(contentsOf: fileURL) else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        if let image = UIImage(data: data, scale: UIScreen.main.scale) {
            return image
        }

        try? FileManager.default.removeItem(at: fileURL)
        return nil
    }

    private func prepareForDisplay(_ image: UIImage) -> UIImage {
        if #available(iOS 15.0, *) {
            return image.preparingForDisplay() ?? image
        }
        return image
    }
}

// MARK: - Shared UI Bits

private struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var material: Material = .ultraThinMaterial
    var strokeOpacity: Double = 0.15
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(.white.opacity(strokeOpacity), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

private extension View {
    func glassCard(
        cornerRadius: CGFloat = 20,
        material: Material = .ultraThinMaterial,
        strokeOpacity: Double = 0.15
    ) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, material: material, strokeOpacity: strokeOpacity))
    }
}

fileprivate func saveIconToGroup(_ image: UIImage, bundleID: String) {
    guard let data = image.pngData(),
          let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.stik.sj")
    else { return }
    let iconsDir = container.appendingPathComponent("icons", isDirectory: true)
    try? FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
    let fileURL = iconsDir.appendingPathComponent("\(bundleID).png")
    try? data.write(to: fileURL)
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

#Preview {
    InstalledAppsListView { _ in }
        .environment(\.colorScheme, .dark)
}

class InstalledAppsViewModel: ObservableObject {
    @Published var debuggableApps: [String: String] = [:]
    @Published var nonDebuggableApps: [String: String] = [:]
    @Published var systemApps: [String: String] = [:]
    @Published var isLoading = false
    @Published var lastError: String? = nil

    private let workQueue = DispatchQueue(label: "com.stik.installedApps", qos: .userInitiated)

    init() { refreshAppLists() }

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
                }
            } catch {
                DispatchQueue.main.async {
                    self.debuggableApps = [:]
                    self.nonDebuggableApps = [:]
                    self.systemApps = [:]
                    self.isLoading = false
                    self.lastError = error.localizedDescription
                    print("Failed to load apps: \(error)")
                }
            }
        }
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

