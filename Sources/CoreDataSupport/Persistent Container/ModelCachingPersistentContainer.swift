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

/// A subclass of `NSPersistentContainer` that prevents loading the managed object model multiple times by caching it.
open class ModelCachingPersistentContainer: NSPersistentContainer {
    private static var _model: NSManagedObjectModel?
    
    private static func loadModel(name: String, bundle: Bundle) throws -> NSManagedObjectModel {
        guard let modelURL = bundle.url(forResource: name, withExtension: "momd") else {
            throw PersistentContainerError.modelURLNotFound(forResourceName: name)
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw PersistentContainerError.modelLoadingFailed(forURL: modelURL)
        }
        return model
    }
    
    /// Load the model with the given name in the given bundle, or return the cached model if it was already loaded.
    ///
    /// This prevents loading the model multiple times.
    /// - Parameters:
    ///   - name: The name of the `NSManagedObjectModel`
    ///   - bundle: The `Bundle` to look for the model file
    /// - Throws: `PersistentContainerError`
    /// - Returns: The loaded model
    public static func model(name: String, in bundle: Bundle) throws -> NSManagedObjectModel {
        if _model == nil {
            _model = try loadModel(name: name, bundle: bundle)
        }
        return _model!
    }
    
    public enum PersistentContainerError: Error {
        case modelURLNotFound(forResourceName: String)
        case modelLoadingFailed(forURL: URL)
    }
    
    public convenience init(name: String) {
        let model = try! Self.model(name: name, in: .init(for: Self.self))
        self.init(name: name, managedObjectModel: model)
    }
    
    /// Initialize with the given name and model.
    ///
    /// The model will be cached.
    /// - Parameters:
    ///   - name: The name used by the persistent container.
    ///   - model: The managed object model to be used by the persistent container.
    public override init(name: String, managedObjectModel model: NSManagedObjectModel) {
        Self._model = model
        super.init(name: name, managedObjectModel: model)
    }
}
