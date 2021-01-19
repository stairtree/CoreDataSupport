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

public protocol ModelVersion: Equatable {
    static var all: [Self] { get }
    static var current: Self { get }
    var name: String { get }
    var successor: Self? { get }
    var modelBundle: Bundle { get }
    var modelDirectoryName: String { get }
    func mappingModelsToSuccessor() -> [NSMappingModel]?
}

extension ModelVersion {
    /// The next version
    public var successor: Self? { return nil }
    
    /// Initialize a version from an SQLite store
    ///
    /// Fails, if the store is not compatible with the `NSManagedObjectModel` the version declares.
    /// - Parameter storeURL: The url of the store to load
    public init?(storeURL: URL) {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil) else { return nil }
        let version = Self.all.first {
            $0.managedObjectModel().isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        guard let result = version else { return nil }
        self = result
    }
    
    public func managedObjectModel() -> NSManagedObjectModel {
        let momURL = modelBundle.url(forResource: name, withExtension: "mom", subdirectory: modelDirectoryName)
        guard let url = momURL else { fatalError("model version \(self) not found") }
        guard let model = NSManagedObjectModel(contentsOf: url) else { fatalError("cannot open model at \(url)") }
        return model
    }
    
    /// All mapping models to the next version
    ///
    /// - Note: Unused for now, but mapping models can be split up to reduce memory consumption.
    ///
    /// See [CoreData Documentation](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/vmCustomizing.html#//apple_ref/doc/uid/TP40004399-CH8-SW9)
    /// - Returns: An array of mapping models from this version to the next.
    public func mappingModelsToSuccessor() -> [NSMappingModel]? {
        mappingModelToSuccessor().map(Array.init)
    }
    
    /// Mapping model to the next version from the model's bundle
    /// - Returns: The mapping model to the next version
    public func mappingModelToSuccessor() -> NSMappingModel? {
        guard let nextVersion = successor else { return nil }
        guard let mapping = NSMappingModel(from: [modelBundle], forSourceModel: managedObjectModel(), destinationModel: nextVersion.managedObjectModel()) else {
            fatalError("no mapping model found for \(self) to \(nextVersion)")
        }
        return mapping
    }
    
    /// Migration steps from this version to the given version
    /// - Parameter version: The desired target version
    /// - Returns: All migration steps to reach the target version
    public func migrationSteps(to version: Self) -> [MigrationStep] {
        guard self != version else { return [] }
        guard let mappings = mappingModelsToSuccessor(), let nextVersion = successor else { fatalError("couldn't find mapping models") }
        let step = MigrationStep(source: managedObjectModel(), destination: nextVersion.managedObjectModel(), mappings: mappings)
        return [step] + nextVersion.migrationSteps(to: version)
    }
}

public final class MigrationStep {
    public var source: NSManagedObjectModel
    public var destination: NSManagedObjectModel
    public var mappings: [NSMappingModel]
    
    init(source: NSManagedObjectModel, destination: NSManagedObjectModel, mappings: [NSMappingModel]) {
        self.source = source
        self.destination = destination
        self.mappings = mappings
    }
}

extension NSManagedObjectContext {
    public convenience init<Version: ModelVersion>(concurrencyType: NSManagedObjectContextConcurrencyType, modelVersion: Version, storeURL: URL, progress: Progress? = nil) {
        if let storeVersion = Version(storeURL: storeURL) , storeVersion != modelVersion {
            migrateStore(from: storeURL, to: storeURL, targetVersion: modelVersion, deleteSource: true, progress: progress)
        }
        let psc = NSPersistentStoreCoordinator(managedObjectModel: modelVersion.managedObjectModel())
        try! psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
        self.init(concurrencyType: concurrencyType)
        persistentStoreCoordinator = psc
    }
}
