//
//  ToolsView.swift
//  StikDebug
//
//  Created by Stephen on 2/23/26.
//

import SwiftUI

struct ToolsView: View {
    var body: some View {
        NavigationStack {
            List(AppFeature.toolList) { tool in
                NavigationLink {
                    tool.destination
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tool.toolTitle)
                            Text(tool.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: tool.systemImage)
                    }
                }
            }
            .navigationTitle(String(format: "Tools".localized))
        }
    }
}
