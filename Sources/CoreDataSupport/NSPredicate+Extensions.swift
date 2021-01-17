//===----------------------------------------------------------------------===//
//
// This source file is part of the Core Data Support open source project
//
// Copyright (c) Stairtree GmbH
// Licensed under the MIT license
//
// See LICENSE.txt and LICENSE.objc.io.txt for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import Foundation

extension NSPredicate {
    /// Predicate for checking if keyPath is `true`
    /// - Parameter keyPath: `@objc` keyPath
    /// - Returns: Predicate for checking if keyPath evaluates to `true`
    public static func isTrue(_ keyPath: String) -> NSPredicate {
        .init(format: "%K = %d", keyPath, true)
    }
    
    /// Predicate for checking if keyPath is `false`
    /// - Parameter keyPath: `@objc` keyPath
    /// - Returns: Predicate for checking if keyPath evaluates to `false`
    public static func isFalse(_ keyPath: String) -> NSPredicate {
        .init(format: "%K = %d", keyPath, false)
    }
    
    /// Equivalent to `NSPredicate(value: true)`
    public static var `true`: NSPredicate = .init(value: true)
    
    /// Equivalent to `NSPredicate(value: false)`
    public static var `false`: NSPredicate = .init(value: false)
}
