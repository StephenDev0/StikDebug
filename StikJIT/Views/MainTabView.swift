//
//  MainTabView.swift
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

import SwiftUI

struct MainTabView: View {
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    
    private var accentColor: Color {
        if customAccentColorHex.isEmpty {
            return .blue
        } else {
            return Color(hex: customAccentColorHex) ?? .blue
        }
    }
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            ScriptListView()
                .tabItem {
                    Label("Scripts", systemImage: "scroll")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .accentColor(accentColor)
        .environment(\.accentColor, accentColor)
    }
}
