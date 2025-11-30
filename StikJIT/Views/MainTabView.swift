//
//  MainTabView.swift
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

import SwiftUI

struct MainTabView: View {
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @State private var selection: Int = 0

    // Update checking
    @State private var showForceUpdate: Bool = false
    @State private var latestVersion: String? = nil

    @Environment(\.themeExpansionManager) private var themeExpansion

    private var accentColor: Color {
        themeExpansion?.resolvedAccentColor(from: customAccentColorHex) ?? .blue
    }
    
    private var preferredScheme: ColorScheme? {
        themeExpansion?.preferredColorScheme(for: appThemeRaw)
    }

    private var isAppStoreBuild: Bool {
        themeExpansion?.isAppStoreBuild ?? true
    }

    var body: some View {
        ZStack {
            // Allow global themed background to show
            Color.clear.ignoresSafeArea()
            
            // Main tabs
            TabView(selection: $selection) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(0)

                ConsoleLogsView()
                    .tabItem { Label("Console", systemImage: "terminal") }
                    .tag(1)

                ScriptListView()
                    .tabItem { Label("Scripts", systemImage: "scroll") }
                    .tag(2)
                
                ProfileView()
                    .tabItem { Label("Profiles", systemImage: "magazine.fill") }
                    .tag(3)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(4)
            }
            .id((themeExpansion?.hasThemeExpansion == true) ? customAccentColorHex : "default-accent")
            .tint(accentColor)
            .preferredColorScheme(preferredScheme)
            .onAppear {
                checkForUpdate()
            }

            if showForceUpdate {
                ZStack {
                    Color.black.opacity(0.001).ignoresSafeArea()

                    appGlassCard {
                        VStack(spacing: 20) {
                            Text("Update Required")
                                .font(.title.bold())
                                .multilineTextAlignment(.center)

                            Text("A new version (\(latestVersion ?? "unknown")) is available. Please update to continue using the app.")
                                .multilineTextAlignment(.center)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            Button(action: {
                                let urlString: String
                                if isAppStoreBuild {
                                    urlString = "itms-apps://itunes.apple.com/app/id6744045754"
                                } else {
                                    urlString = "altstore://source?url=https://StikDebug.xyz/apps.json"
                                }
                                if let url = URL(string: urlString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Update Now")
                                    .font(.headline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.accentColor)
                                    )
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut, value: showForceUpdate)
            }
        }
    }

    // MARK: - Update Checker
    private func checkForUpdate() {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }

        fetchLatestVersion { latest in
            latestVersion = latest
            if let latest = latest,
               latest.compare(currentVersion, options: .numeric) == .orderedDescending {
                DispatchQueue.main.async {
                    showForceUpdate = true
                }
            }
        }
    }

    private func fetchLatestVersion(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=6744045754") else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let appStoreVersion = results.first?["version"] as? String {
                    completion(appStoreVersion)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .themeExpansionManager(ThemeExpansionManager(previewUnlocked: true))
    }
}
