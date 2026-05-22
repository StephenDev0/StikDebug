//
//  AutoScriptAssignments.swift
//  StikDebug
//

private struct AutoScriptAssignment {
    let appNames: Set<String>
    let resource: ScriptResource
}

extension ScriptStore {
    private static let autoScriptAssignments: [AutoScriptAssignment] = [
        AutoScriptAssignment(
            appNames: [
                "Amethyst",
                "MeloNX",
                "Melo",
                "XeniOS",
                "MeloCafe",
                "Manic EMU",
                "Manic",
                "Geode",
                "DukeX",
                "Duke X",
                "Duke"
            ],
            resource: ScriptResource(resourceName: "universal", fileName: "universal.js")
        ),
        AutoScriptAssignment(
            appNames: [
                "UTM",
                "DolphiniOS",
                "Flycast"
            ],
            resource: ScriptResource(resourceName: "UTM-Dolphin", fileName: "UTM-Dolphin.js")
        ),
        AutoScriptAssignment(
            appNames: [
                "maciOS"
            ],
            resource: ScriptResource(resourceName: "maciOS", fileName: "maciOS.js")
        )
    ]

    static func autoScriptResource(for appName: String) -> ScriptResource? {
        autoScriptAssignments.first { assignment in
            assignment.appNames.contains(appName)
        }?.resource
    }
}
