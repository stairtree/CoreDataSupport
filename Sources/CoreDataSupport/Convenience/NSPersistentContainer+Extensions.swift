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

import CoreData

extension NSPersistentContainer {
    /// Synchronously load the persistent stores
    /// - Throws: Errors that occurred during loading
    /// - Returns: The descriptions of all persistent stores that were loaded
    @discardableResult
    public func loadPersistentStores() throws -> [NSPersistentStoreDescription] {
        var error: Error? = nil
        var descriptions: [NSPersistentStoreDescription] = []
        
        self.persistentStoreDescriptions.forEach { $0.shouldAddStoreAsynchronously = false }
        self.loadPersistentStores(completionHandler: { probablyDescription, maybeError in
            error = error ?? maybeError
            descriptions.append(probablyDescription)
        })
        if let error = error {
            throw error
        }
        return descriptions
    }
}
