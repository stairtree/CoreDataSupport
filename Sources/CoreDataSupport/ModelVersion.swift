//
//  ModelVersionType.swift
//  Migrations
//
//  Created by Florian on 06/10/15.
//  Copyright © 2015 objc.io. All rights reserved.
//

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
    
    public var successor: Self? { return nil }
    
    public init?(storeURL: URL) {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil) else { return nil }
        let version = Self.all.first {
            $0.managedObjectModel().isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        guard let result = version else { return nil }
        self = result
    }
    
    public func managedObjectModel() -> NSManagedObjectModel {
//        let omoURL = modelBundle.url(forResource: name, withExtension: "omo", subdirectory: modelDirectoryName)
        let momURL = modelBundle.url(forResource: name, withExtension: "mom", subdirectory: modelDirectoryName)
        guard let url = momURL else { fatalError("model version \(self) not found") }
        guard let model = NSManagedObjectModel(contentsOf: url) else { fatalError("cannot open model at \(url)") }
        return model
    }
    
    public func mappingModelsToSuccessor() -> [NSMappingModel]? {
        guard let mapping = mappingModelToSuccessor() else { return nil }
        return [mapping]
    }
    
    public func mappingModelToSuccessor() -> NSMappingModel? {
        guard let nextVersion = successor else { return nil }
        guard let mapping = NSMappingModel(from: [modelBundle], forSourceModel: managedObjectModel(), destinationModel: nextVersion.managedObjectModel()) else {
            fatalError("no mapping model found for \(self) to \(nextVersion)")
        }
        return mapping
    }
    
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
    
    init(source: NSManagedObjectModel, destination: NSManagedObjectModel, mappings: [NSMappingModel])
    {
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
