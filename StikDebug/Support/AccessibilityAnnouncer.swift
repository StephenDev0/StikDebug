//
//  AccessibilityAnnouncer.swift
//  StikDebug
//

import UIKit

enum AccessibilityAnnouncer {
    static func announce(_ message: String) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
