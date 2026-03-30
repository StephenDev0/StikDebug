//
//  Security.swift
//  StikJIT
//  from MeloNX
//  Created by s s on 2025/4/6.
//
import Foundation
import Security

typealias SecTaskRef = OpaquePointer

@_silgen_name("SecTaskCopyValueForEntitlement")
func SecTaskCopyValueForEntitlement(
    _ task: SecTaskRef,
    _ entitlement: CFString,
    _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?
) -> CFTypeRef?

@_silgen_name("SecTaskCreateFromSelf")
func SecTaskCreateFromSelf(
    _ allocator: CFAllocator?
) -> SecTaskRef?

func checkAppEntitlement(_ ent: String) -> Bool {
    guard let task = SecTaskCreateFromSelf(nil) else { return false }
    guard let value = SecTaskCopyValueForEntitlement(task, ent as CFString, nil) else { return false }
    return value.boolValue != nil && value.boolValue
}
