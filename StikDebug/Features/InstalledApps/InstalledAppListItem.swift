//
//  InstalledAppListItem.swift
//  StikDebug
//

import Foundation

struct InstalledAppListItem: Identifiable, Equatable {
    let bundleID: String
    let name: String

    private let normalizedBundleID: String
    private let normalizedName: String

    var id: String {
        bundleID
    }

    init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
        self.normalizedBundleID = Self.normalized(bundleID)
        self.normalizedName = Self.normalized(name)
    }

    func matches(_ query: String) -> Bool {
        query.isEmpty || normalizedBundleID.contains(query) || normalizedName.contains(query)
    }

    static func sorted(from apps: [String: String]) -> [InstalledAppListItem] {
        apps.map { InstalledAppListItem(bundleID: $0.key, name: $0.value) }
            .sorted { lhs, rhs in
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if comparison == .orderedSame {
                    return lhs.bundleID < rhs.bundleID
                }
                return comparison == .orderedAscending
            }
    }

    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
