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
                "PocketJ Launcher",
                "掌上Java启动器",
                "MeloNX",
                "Melo",
                "XeniOS",
                "MeloCafe",
                "Manic EMU",
                "Manic",
                "DukeX",
                "TachyonU",
                "touchHLE",
                "HyperHLE",
                "Applesauce"
            ],
            resource: ScriptResource(resourceName: "universal", fileName: "universal.js")
        ),
        AutoScriptAssignment(
            appNames: [
                "Geode"
            ],
            resource: ScriptResource(resourceName: "Geode", fileName: "Geode.js")
        ),
        AutoScriptAssignment(
            appNames: [
                "UTM",
                "DolphiniOS",
                "Flycast",
                "ARMSX2 iOS"
            ],
            resource: ScriptResource(resourceName: "legacy", fileName: "legacy.js")
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
