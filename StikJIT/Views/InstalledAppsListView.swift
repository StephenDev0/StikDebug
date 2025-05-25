//
//  InstalledAppsListView.swift
//  StikJIT
//
//  Created by Stossy11 on 28/03/2025.
//

import SwiftUI

struct InstalledAppsListView: View {
    @StateObject private var viewModel = InstalledAppsViewModel()
    @State private var appIcons: [String: UIImage] = [:]
    @Environment(\.dismiss) private var dismiss
    @AppStorage("recentApps") var recentApps: [String] = []
    var onSelectApp: (String) -> Void

    var body: some View {
        if viewModel.apps.isEmpty {
            NavigationView {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray)
                    
                    Text("No Debuggable App Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("StikDebug can only connect to apps with the \"**get-task-allow**\" entitlement. Please check if the app you want to connect to is signed with a **development** certificate.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .toolbar(content: {
                    Button("Done") {
                        dismiss()
                    }
                })
            }

        } else {
            
            NavigationView {
                List {
                    if !recentApps.isEmpty {
                        Section {
                            ForEach(recentApps, id: \.self) { bundleID in
                                AppButton(bundleID: bundleID, appName: viewModel.apps[bundleID] ?? "", recentApps: $recentApps, appIcons: $appIcons, onSelectApp: onSelectApp)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                recentApps.removeAll(where: { $0 == bundleID })
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            Text("Recents")
                        }
                    }
                    Section {
                        ForEach(viewModel.apps.sorted(by: { $0.key < $1.key }), id: \.key) { bundleID, appName in
                            AppButton(bundleID: bundleID, appName: appName, recentApps: $recentApps, appIcons: $appIcons, onSelectApp: onSelectApp)
                        }
                    } header: {
                        if !recentApps.isEmpty {
                            Text("All applications")
                        } else {
                            EmptyView()
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Installed Apps")
                .toolbar(content: {
                    Button("Done") {
                        dismiss()
                    }
                })
            }
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        }
    }
}

struct AppButton: View {
    @State var bundleID: String
    @State var appName: String
    @Binding var recentApps: [String]
    @Binding var appIcons: [String: UIImage]
    @AppStorage("loadAppIconsOnJIT") private var loadAppIconsOnJIT = true
    var onSelectApp: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            recentApps.removeAll(where: { $0 == bundleID })
            recentApps.insert(bundleID, at: 0)
            if recentApps.count > 3 {
                recentApps = Array(recentApps.prefix(3))
            }
            onSelectApp(bundleID)
        }) {
            HStack(spacing: loadAppIconsOnJIT ? 16 : 12) {
                if loadAppIconsOnJIT {
                    if let image = appIcons[bundleID] {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .cornerRadius(12)
                            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.2), radius: 3, x: 0, y: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "app")
                                    .font(.system(size: 26))
                                    .foregroundColor(.gray)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            .onAppear {
                                loadAppIcon(for: bundleID)
                            }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(.label))
                    Text(bundleID)
                        .font(.system(size: 15))
                        .foregroundColor(Color.gray)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, loadAppIconsOnJIT ? 0 : 8)
        }
    }

    private func loadAppIcon(for bundleID: String) {
        if loadAppIconsOnJIT {
            AppStoreIconFetcher.getIcon(for: bundleID) { image in
                if let image = image {
                    DispatchQueue.main.async {
                        withAnimation(.easeIn(duration: 0.2)) {
                            self.appIcons[bundleID] = image
                        }
                    }
                }
            }
        }
    }
}

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

#Preview {
    InstalledAppsListView { _ in }
}
