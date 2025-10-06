//
//  DebugWidgetBundle.swift
//  DebugWidget
//
//  Created by Stephen on 5/30/25.
//

import WidgetKit
import SwiftUI

@main
struct StikDebugWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Both widgets enabled: Favorites uses enable-jit URL scheme (with continued-processing handled in-app),
        // System Apps uses launch-app URL scheme for non-debug launch behavior.
        FavoritesWidget()
        SystemAppsWidget()
    }
}
