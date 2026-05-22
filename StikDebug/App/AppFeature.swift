//
//  AppFeature.swift
//  StikDebug
//

import SwiftUI

enum AppFeature: String, CaseIterable, Identifiable {
    case home
    case scripts
    case tools
    case news
    case console
    case deviceInfo = "deviceinfo"
    case profiles
    case processes
    case location
    case settings

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .home:
            return String(format: "Apps".localized)
        case .scripts:
            return String(format: "Scripts".localized)
        case .tools:
            return String(format: "Tools".localized)
        case .news:
            return String(format: "News".localized)
        case .console:
            return String(format: "Console".localized)
        case .deviceInfo:
            return String(format: "Device Info".localized)
        case .profiles:
            return String(format: "App Expiry".localized)
        case .processes:
            return String(format: "Processes".localized)
        case .location:
            return String(format: "Location".localized)
        case .settings:
            return String(format: "Settings".localized)
        }
    }

    var detail: String {
        switch self {
        case .home:
            return String(format: "Manage installed apps".localized)
        case .scripts:
            return String(format: "Manage and run JS scripts".localized)
        case .tools:
            return String(format: "Access additional tools".localized)
        case .news:
            return String(format: "Latest StikDebug updates".localized)
        case .console:
            return String(format: "Live device logs".localized)
        case .deviceInfo:
            return String(format: "View detailed device metadata".localized)
        case .profiles:
            return String(format: "Check app expiration dates".localized)
        case .processes:
            return String(format: "Inspect running apps".localized)
        case .location:
            return String(format: "Simulate GPS location".localized)
        case .settings:
            return String(format: "Configure StikDebug".localized)
        }
    }

    var toolTitle: String {
        switch self {
        case .location:
            return String(format: "Location Simulation".localized)
        default:
            return title
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "square.grid.2x2"
        case .scripts:
            return "scroll"
        case .tools:
            return "wrench.and.screwdriver"
        case .news:
            return "newspaper"
        case .console:
            return "terminal"
        case .deviceInfo:
            return "iphone.and.arrow.forward"
        case .profiles:
            return "calendar.badge.clock"
        case .processes:
            return "rectangle.stack.person.crop"
        case .location:
            return "location"
        case .settings:
            return "gearshape.fill"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .home:
            HomeView()
        case .scripts:
            ScriptListView()
        case .tools:
            ToolsView()
        case .news:
            NewsView()
        case .console:
            ConsoleLogsView()
        case .deviceInfo:
            DeviceInfoView()
        case .profiles:
            ProfileView()
        case .processes:
            ProcessInspectorView()
        case .location:
            LocationSimulationView()
        case .settings:
            SettingsView()
        }
    }
}

extension AppFeature {
    static let mainTabs: [AppFeature] = [.home, .tools, .news, .settings]
    static let toolList: [AppFeature] = [.scripts, .console, .deviceInfo, .profiles, .processes, .location]
}
