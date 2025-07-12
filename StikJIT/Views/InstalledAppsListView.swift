//
//  InstalledAppsListView.swift
//  StikJIT
//
//  Created by Stossy11 on 28/03/2025.
//

import SwiftUI
import UIKit
import WidgetKit

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
            sharedDefaults.set(favoriteApps, forKey: "favoriteApps")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @Environment(\.dismiss) private var dismiss
    var onSelectApp: (String) -> Void

    private var filteredRecents: [String] {
        recentApps.filter { !favoriteApps.contains($0) }
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.apps.isEmpty {
                    emptyState
                } else {
                    appsList
                }
            }
            .navigationTitle("Installed Apps".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .resizable().scaledToFit().frame(width: 60, height: 60).foregroundColor(.gray)
            Text("No Debuggable App Found")
                .font(.title2).fontWeight(.semibold).foregroundColor(.primary)
            Text("""
StikDebug can only connect to apps with the "**get-task-allow**" entitlement. \
Please check if the app you want to connect to is signed with a **development** certificate.
""")
                .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
        }
        .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    private var appsList: some View {
        List {
            if !favoriteApps.isEmpty {
                Section(header: Text(String(format: "Favorites (%d/4)".localized, favoriteApps.count))) {
                    ForEach(favoriteApps, id: \.self) { bundleID in
                        AppButton(
                            bundleID: bundleID,
                            appName: viewModel.apps[bundleID] ?? bundleID,
                            recentApps: $recentApps,
                            favoriteApps: $favoriteApps,
                            appIcons: $appIcons,
                            onSelectApp: onSelectApp,
                            sharedDefaults: sharedDefaults
                        )
                    }
                }
            }

            if !filteredRecents.isEmpty {
                Section(header: Text("Recents".localized)) {
                    ForEach(filteredRecents, id: \.self) { bundleID in
                        AppButton(
                            bundleID: bundleID,
                            appName: viewModel.apps[bundleID] ?? bundleID,
                            recentApps: $recentApps,
                            favoriteApps: $favoriteApps,
                            appIcons: $appIcons,
                            onSelectApp: onSelectApp,
                            sharedDefaults: sharedDefaults
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    recentApps.removeAll { $0 == bundleID }
                                    sharedDefaults.set(recentApps, forKey: "recentApps")
                                    WidgetCenter.shared.reloadAllTimelines()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section(header: Text((favoriteApps.isEmpty && filteredRecents.isEmpty) ? "" : "All Applications".localized)) {
                ForEach(viewModel.apps.sorted(by: { $0.key < $1.key }), id: \.key) { bundleID, appName in
                    AppButton(
                        bundleID: bundleID,
                        appName: appName,
                        recentApps: $recentApps,
                        favoriteApps: $favoriteApps,
                        appIcons: $appIcons,
                        onSelectApp: onSelectApp,
                        sharedDefaults: sharedDefaults
                    )
                }
            }
        }
        .listStyle(.plain)
    }
}

struct AppButton: View {
    let bundleID: String
    let appName: String
    @Binding var recentApps: [String]
    @Binding var favoriteApps: [String]
    @Binding var appIcons: [String: UIImage]
    @AppStorage("loadAppIconsOnJIT") private var loadAppIconsOnJIT = true
    var onSelectApp: (String) -> Void
    let sharedDefaults: UserDefaults

    @Environment(\.colorScheme) private var colorScheme
    @State private var showScriptPicker = false

    var body: some View {
        Button(action: selectApp) {
            HStack(spacing: loadAppIconsOnJIT ? 16 : 12) {
                iconView
                appText
                Spacer()
            }
            .padding(.vertical, loadAppIconsOnJIT ? 0 : 8)
        }
        .contextMenu {
            Button(action: toggleFavorite) {
                Label(
                    favoriteApps.contains(bundleID) ? "Remove Favorite" : "Add to Favorites",
                    systemImage: favoriteApps.contains(bundleID) ? "star.slash" : "star"
                )
                .disabled(!favoriteApps.contains(bundleID) && favoriteApps.count >= 4)
            }
            Button { UIPasteboard.general.string = bundleID } label: {
                Label("Copy Bundle ID", systemImage: "doc.on.doc")
            }
            Button {
                showScriptPicker = true
            } label: {
                Label("Assign Script", systemImage: "chevron.left.slash.chevron.right")
            }
        }
        .sheet(isPresented: $showScriptPicker) {
            ScriptListView { url in
                assignScript(url)
                showScriptPicker = false
            }
        }
    }

    private var iconView: some View {
        Group {
            if loadAppIconsOnJIT, let image = appIcons[bundleID] {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.2) : .gray.opacity(0.2), radius: 3, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "app")
                            .font(.system(size: 26))
                            .foregroundColor(.gray)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .onAppear { loadAppIcon(for: bundleID) }
            }
        }
    }

    private var appText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            Text(bundleID)
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
    }

    private func selectApp() {
        recentApps.removeAll { $0 == bundleID }
        recentApps.insert(bundleID, at: 0)
        if recentApps.count > 3 { recentApps = Array(recentApps.prefix(3)) }
        sharedDefaults.set(recentApps, forKey: "recentApps")
        sharedDefaults.set(favoriteApps, forKey: "favoriteApps")
        WidgetCenter.shared.reloadAllTimelines()
        onSelectApp(bundleID)
    }

    private func toggleFavorite() {
        if favoriteApps.contains(bundleID) {
            favoriteApps.removeAll { $0 == bundleID }
        } else if favoriteApps.count < 4 {
            favoriteApps.insert(bundleID, at: 0)
            recentApps.removeAll { $0 == bundleID }
        }
        sharedDefaults.set(recentApps, forKey: "recentApps")
        sharedDefaults.set(favoriteApps, forKey: "favoriteApps")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func assignScript(_ url: URL) {
        var mapping = UserDefaults.standard.dictionary(forKey: "BundleScriptMap") as? [String: String] ?? [:]
        mapping[bundleID] = url.lastPathComponent
        UserDefaults.standard.set(mapping, forKey: "BundleScriptMap")
    }

    private func loadAppIcon(for bundleID: String) {
        guard loadAppIconsOnJIT else { return }

        // 1) Check disk cache first
        if let cachedImage = loadCachedIcon(bundleID: bundleID) {
            DispatchQueue.main.async {
                appIcons[bundleID] = cachedImage
            }
            return
        }

        // 2) Otherwise fetch from network and then cache
        AppStoreIconFetcher.getIcon(for: bundleID) { image in
            guard let image = image else { return }
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.2)) {
                    appIcons[bundleID] = image
                }
            }
            saveIconToGroup(image, bundleID: bundleID)
        }
    }

    private func loadCachedIcon(bundleID: String) -> UIImage? {
        guard
            let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.stik.sj")
        else { return nil }

        let iconsDir = containerURL.appendingPathComponent("icons", isDirectory: true)
        let fileURL = iconsDir.appendingPathComponent("\(bundleID).png")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return UIImage(contentsOfFile: fileURL.path)
        }
        return nil
    }
}

fileprivate func saveIconToGroup(_ image: UIImage, bundleID: String) {
    guard
        let data = image.pngData(),
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.stik.sj")
    else { return }

    let iconsDir = container.appendingPathComponent("icons", isDirectory: true)
    try? FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
    let fileURL = iconsDir.appendingPathComponent("\(bundleID).png")
    try? data.write(to: fileURL)
}

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

// Preview helper
#Preview {
    InstalledAppsListView { _ in }
}
