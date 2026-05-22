//
//  FileManager+Lookup.swift
//  StikDebug
//

import Foundation

extension FileManager {
    func filePath(atPath path: String, withLength length: Int) -> String? {
        guard let file = try? contentsOfDirectory(atPath: path).first(where: { $0.count == length }) else {
            return nil
        }

        return "\(path)/\(file)"
    }
}
