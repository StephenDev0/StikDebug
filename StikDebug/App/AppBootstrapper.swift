//
//  AppBootstrapper.swift
//  StikDebug
//

import Foundation
import ObjectiveC.runtime
import UIKit

enum AppBootstrapper {
    static func configure() {
        registerDefaultSettings()
        startConfiguredKeepAliveServices()
        applyDocumentPickerCopyWorkaround()
        NetworkPathMonitor.shared.start()
    }

    private static func registerDefaultSettings() {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let enableAdvancedOptions = os.majorVersion >= 19

        UserDefaults.standard.register(defaults: [
            "enableAdvancedOptions": enableAdvancedOptions,
            UserDefaults.Keys.txmOverride: false,
            UserDefaults.Keys.confirmExternalJITRequests: true,
            "keepAliveAudio": true,
            "keepAliveLocation": true
        ])
    }

    private static func startConfiguredKeepAliveServices() {
        guard UserDefaults.standard.bool(forKey: "keepAliveAudio") else {
            return
        }
        BackgroundAudioManager.shared.start()
    }

    private static func applyDocumentPickerCopyWorkaround() {
        let fixedSelector = NSSelectorFromString("fix_initForOpeningContentTypes:asCopy:")
        let originalSelector = #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:))

        guard let fixedMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, fixedSelector),
              let originalMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, originalSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, fixedMethod)
    }
}
