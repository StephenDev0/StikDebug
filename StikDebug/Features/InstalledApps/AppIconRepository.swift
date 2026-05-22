//
//  AppIconRepository.swift
//  StikDebug
//

import SwiftUI
import UIKit

enum AppIconRepository {
    private static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 2_000
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    private static let diskQueue = DispatchQueue(label: "com.stik.iconcache.disk", qos: .utility)
    private static let fetchSemaphore = AsyncSemaphore(permits: 4)
    private static let registry = IconFetchRegistry()
    private static let appGroupIdentifier = "group.com.stik.sj"

    static func cachedImage(for bundleID: String) -> UIImage? {
        memory.object(forKey: bundleID as NSString)
    }

    static func image(for bundleID: String) async -> UIImage? {
        if let memoryImage = cachedImage(for: bundleID) {
            return memoryImage
        }

        if let diskImage = await loadFromDisk(bundleID: bundleID) {
            storeInMemory(diskImage, for: bundleID)
            return diskImage
        }

        return await fetchAndStore(bundleID: bundleID)
    }

    static func prefetch(bundleIDs: [String]) {
        for bundleID in Set(bundleIDs) {
            Task.detached(priority: .utility) {
                _ = await image(for: bundleID)
            }
        }
    }

    private static func fetchAndStore(bundleID: String) async -> UIImage? {
        let task = await registry.task(for: bundleID) {
            Task.detached(priority: .utility) {
                await fetchSemaphore.acquire()

                let result: UIImage?
                if let fetched = await fetchFromSource(bundleID: bundleID) {
                    let prepared = prepareForDisplay(fetched)
                    store(prepared, for: bundleID)
                    result = prepared
                } else {
                    result = nil
                }

                await fetchSemaphore.release()
                await registry.clear(bundleID: bundleID)
                return result
            }
        }

        return await task.value
    }

    private static func fetchFromSource(bundleID: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            AppStoreIconFetcher.getIcon(for: bundleID) { image in
                continuation.resume(returning: image)
            }
        }
    }

    private static func loadFromDisk(bundleID: String) async -> UIImage? {
        let imageScale = await MainActor.run { UIScreen.main.scale }

        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            diskQueue.async {
                guard let url = iconURL(for: bundleID),
                      FileManager.default.fileExists(atPath: url.path) else {
                    continuation.resume(returning: nil)
                    return
                }

                guard let data = try? Data(contentsOf: url) else {
                    try? FileManager.default.removeItem(at: url)
                    continuation.resume(returning: nil)
                    return
                }

                guard let image = UIImage(data: data, scale: imageScale) else {
                    try? FileManager.default.removeItem(at: url)
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: prepareForDisplay(image))
            }
        }
    }

    private static func store(_ image: UIImage, for bundleID: String) {
        storeInMemory(image, for: bundleID)
        storeOnDisk(image, bundleID: bundleID)
    }

    private static func storeInMemory(_ image: UIImage, for bundleID: String) {
        memory.setObject(image, forKey: bundleID as NSString, cost: memoryCost(for: image))
    }

    private static func storeOnDisk(_ image: UIImage, bundleID: String) {
        diskQueue.async {
            guard let url = iconURL(for: bundleID),
                  let data = image.pngData() else {
                return
            }

            try? data.write(to: url, options: .atomic)
        }
    }

    private static func iconURL(for bundleID: String) -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier),
              let fileName = cacheFileName(for: bundleID) else {
            return nil
        }

        let directory = container.appendingPathComponent("icons", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        return directory.appendingPathComponent(fileName)
    }

    private static func cacheFileName(for bundleID: String) -> String? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        let sanitized = String(bundleID.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })

        guard !sanitized.isEmpty else {
            return nil
        }

        return "\(sanitized).png"
    }

    private static func memoryCost(for image: UIImage) -> Int {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        return max(width * height * 4, 1)
    }

    private static func prepareForDisplay(_ image: UIImage) -> UIImage {
        image.preparingForDisplay() ?? image
    }
}

@MainActor
final class IconLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private let bundleID: String
    private var didStart = false

    init(bundleID: String) {
        self.bundleID = bundleID
        if let cached = AppIconRepository.cachedImage(for: bundleID) {
            image = cached
            didStart = true
        }
    }

    func beginLoading() {
        if image != nil {
            didStart = true
            return
        }

        guard !didStart else {
            return
        }

        didStart = true
        let targetID = bundleID

        Task { [weak self] in
            if let resolved = await AppIconRepository.image(for: targetID) {
                guard let self else { return }
                withAnimation(.linear(duration: 0.12)) {
                    self.image = resolved
                }
            } else {
                self?.didStart = false
            }
        }
    }
}

private actor IconFetchRegistry {
    private var tasks: [String: Task<UIImage?, Never>] = [:]

    func task(for bundleID: String, create: () -> Task<UIImage?, Never>) -> Task<UIImage?, Never> {
        if let existing = tasks[bundleID] {
            return existing
        }

        let task = create()
        tasks[bundleID] = task
        return task
    }

    func clear(bundleID: String) {
        tasks[bundleID] = nil
    }
}

private actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(permits: Int) {
        self.permits = permits
    }

    func acquire() async {
        if permits > 0 {
            permits -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            permits += 1
        }
    }
}
