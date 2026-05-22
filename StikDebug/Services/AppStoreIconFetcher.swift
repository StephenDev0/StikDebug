//
//  IconsFetcher.swift
//  Dont change the name of the actual file (it will break stuff)
//  StikDebug
//
//  Created by neoarz on 3/28/25.
//

import UIKit

class AppStoreIconFetcher {
    private static var cache = [String: UIImage]()
    private static let queue = DispatchQueue(label: "com.stik.stikdebug.iconFetchQueue", attributes: .concurrent)

    static func getIcon(for bundleID: String, completion: @escaping (UIImage?) -> Void) {
        if let icon = cache[bundleID] {
            completion(icon)
            return
        }

        queue.async {
            let icon = try? JITEnableContext.shared.getAppIcon(withBundleId: bundleID)
            DispatchQueue.main.async {
                if let img = icon {
                    cache[bundleID] = img
                }
                completion(icon)
            }
        }
    }
}
