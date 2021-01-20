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
import Logging

/// A `ValueTransformer` which accepts a generic type `T` as input that must be
/// both `AnyObject` and `Codable` (checked at runtime) and uses binary plist
/// encoding to transform values between `T` and `Data` in such a fashion that
/// `T` need not be statically known as `Codable` (due to limitations of both
/// Foundation and Swift's type system in general).
public class CodableDataTransformer<T>: Foundation.ValueTransformer {

    /// This `Box` implements `Codable` just sufficiently to get at `Encoder`
    /// and `Decoder` instances so `T`'s (runtime-checked) `Codable` conformance
    /// can be invoked via existential syntax.
    private struct Box: Codable {
        let value: T
        init(_ value: T) { self.value = value }
        init(from decoder: Decoder) throws { self.value = try (T.self as! Codable.Type).init(from: decoder) as! T }
        func encode(to encoder: Encoder) throws { try (self.value as! Codable).encode(to: encoder) }
    }

    public override required init() {
        precondition(T.self is Codable.Type && T.self is AnyObject.Type, "CodableDataTransformer's operand type must be AnyObject and Codable")
        super.init()
        Foundation.ValueTransformer.setValueTransformer(self, forName: self.valueTransformerName)
    }
    
    public var valueTransformerName: NSValueTransformerName { .init(Self.name) }
    public static var name: String { "\(T.self)CodableDataTransformer" }
    
    /// Register a transformer instance for type `T` if necessary and return the
    /// name of the transformer.
    public static func make() -> String {
        return Foundation.ValueTransformer(forName: .init(self.name)).map { _ in self.name } ?? self.init().valueTransformerName.rawValue
    }

    public override static func transformedValueClass() -> AnyClass { NSData.self }
    public override static func allowsReverseTransformation() -> Bool { true }
    
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let someValue = value, let tValue = someValue as? T else { return nil }
        return try? PropertyListEncoder().encode(Box(tValue)) as NSData
    }
    
    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let realValue = value, let dataValue = realValue as? NSData else { return nil }
        return try? PropertyListDecoder().decode(Box.self, from: dataValue as Data)
    }
}

/// Interesting settings on an attribute description.
public enum AttributeConstraint<T> {
    case required, transient, defaultValue(T?)
    
    fileprivate func apply(to attr: NSAttributeDescription) {
        switch self {
            case .required: attr.isOptional = false
            case .transient: attr.isTransient = true
            case .defaultValue(let v): attr.defaultValue = v
        }
    }
}

/// Helper object for building up an entity object attribute by attribute.
public class EntityBuilder {
    
    fileprivate var entity: NSEntityDescription
    fileprivate let logger: Logger
    
    fileprivate init(type: NSManagedObject.Type, name: String? = nil, logger: Logger = Logger(label: "EntityBuilder")) {
        self.logger = logger
        self.entity = NSEntityDescription()
        self.entity.managedObjectClassName = NSStringFromClass(type)
        self.entity.name = name ?? self.entity.managedObjectClassName
    }
    
    private func appendAttribute<T>(name: String, type: NSAttributeType, transformer: String? = nil, constraints: [AttributeConstraint<T>]) {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.valueTransformerName = transformer
        constraints.forEach { $0.apply(to: attr) }
        self.entity.properties.append(attr)
    }
    
    @discardableResult
    public func attribute<T>(_ name: String, _ type: T.Type = T.self, _ constraints: AttributeConstraint<T>...) -> Self {
        switch type {
            case is Int16.Type, is UInt16.Type:     self.appendAttribute(name: name, type: .integer16AttributeType, constraints: constraints)
            case is Int32.Type, is UInt32.Type:     self.appendAttribute(name: name, type: .integer32AttributeType, constraints: constraints)
            case is Int64.Type, is UInt64.Type:     self.appendAttribute(name: name, type: .integer64AttributeType, constraints: constraints)
            case is Int.Type, is UInt.Type:         self.appendAttribute(name: name, type: .integer64AttributeType, constraints: constraints)
            case is Decimal.Type:                   self.appendAttribute(name: name, type: .decimalAttributeType, constraints: constraints)
            case is Double.Type:                    self.appendAttribute(name: name, type: .doubleAttributeType, constraints: constraints)
            case is Float.Type:                     self.appendAttribute(name: name, type: .floatAttributeType, constraints: constraints)
            case is String.Type, is Substring.Type: self.appendAttribute(name: name, type: .stringAttributeType, constraints: constraints)
            case is Bool.Type:                      self.appendAttribute(name: name, type: .booleanAttributeType, constraints: constraints)
            case is Date.Type:                      self.appendAttribute(name: name, type: .dateAttributeType, constraints: constraints)
            case is Data.Type:                      self.appendAttribute(name: name, type: .binaryDataAttributeType, constraints: constraints)
            case is UUID.Type:                      self.appendAttribute(name: name, type: .UUIDAttributeType, constraints: constraints)
            case is URL.Type:                       self.appendAttribute(name: name, type: .URIAttributeType, constraints: constraints)
            case is NSSecureCoding.Type:            self.appendAttribute(name: name, type: .transformableAttributeType, constraints: constraints)
            case is (Codable & AnyObject).Type:
                self.appendAttribute(name: name, type: .transformableAttributeType, transformer: CodableDataTransformer<T>.make(), constraints: constraints)
            default:
                logger.warning("Using undefined attribute type for indeterminate Swift type \(T.self)")
                self.appendAttribute(name: name, type: .undefinedAttributeType, constraints: constraints)
        }
        return self
    }

}

/// Helper object for building up a managed object model entity by entity and
/// relation by relation.
public struct ManagedObjectModelBuilder {
    
    fileprivate var entities: [String: NSEntityDescription] = [:]
    
    fileprivate init() {}
    
    /// Invoke a closure with a builder helper object to define an entity of a
    /// given managed object type with a given name (defaults to the class name)
    /// and having the attributes provided by the closure. A given managed
    /// object type may be associated with only one entity.
    public mutating func entity<M: NSManagedObject>(for type: M.Type = M.self, name: String? = nil, builder: (EntityBuilder) -> Void) {
        guard self.entities[NSStringFromClass(type)] == nil else {
            fatalError("Tried to build more than one entity description for managed object type \(type).")
        }
        let superEntity = self.entities[NSStringFromClass(type.superclass()!)]
        guard type.superclass() == NSManagedObject.self || superEntity != nil else {
            fatalError("Tried to build entity of type \(type) before building its superclass type \(type.superclass()!).")
        }
        
        let helper = EntityBuilder(type: type, name: name)

        builder(helper)
        if let existingSuperEntity = superEntity {
            existingSuperEntity.subentities.append(helper.entity)
        }
        self.entities[helper.entity.managedObjectClassName] = helper.entity
    }
    
    /// As per `entity(for:name:builder:)`, but creates an abstract entity.
    public mutating func abstractEntity<M: NSManagedObject>(for type: M.Type = M.self, name: String? = nil, builder: (EntityBuilder) -> Void) {
        self.entity(for: type, name: name, builder: builder)
        self.entities[NSStringFromClass(type)]?.isAbstract = true
    }
    
    /// Create a one-to-one relation between two models. The `fromName` is the
    /// name of the referring property on the first model, while the `toName` is
    /// the name of the inverse-referring property on the second model.
    public mutating func relate<M1: NSManagedObject, M2: NSManagedObject>(_ from: M1.Type = M1.self, _ fromName: String, toOne: M2.Type = M2.self, _ toName: String) {
        return relate(a: from, b: toOne, aName: fromName, bName: toName, fromMany: false, toMany: false, ordered: false)
    }
    
    /// Create an unordered one-to-many relation between two models. The from
    /// model's property will be a Set of the second model, while the to model's
    /// property will be a single instance of the first model.
    public mutating func relate<M1: NSManagedObject, M2: NSManagedObject>(_ from: M1.Type = M1.self, _ fromName: String, toMany: M2.Type = M2.self, _ toName: String) {
        return relate(a: from, b: toMany, aName: fromName, bName: toName, fromMany: false, toMany: true, ordered: false)
    }
    
    /// Create an ordered one-to-many relation between two models. The from
    /// model's property will be an Array of the second model, while the to
    /// model's property will be a single instance of the first model.
    public mutating func relate<M1: NSManagedObject, M2: NSManagedObject>(_ from: M1.Type = M1.self, _ fromName: String, toManyOrdered: M2.Type = M2.self, _ toName: String) {
        return relate(a: from, b: toManyOrdered, aName: fromName, bName: toName, fromMany: false, toMany: true, ordered: true)
    }

    /// Create an unordered many-to-many relation between two models. The
    /// properties on both models will be Sets of the opposite model.
    public mutating func relate<M1: NSManagedObject, M2: NSManagedObject>(many from: M1.Type = M1.self, _ fromName: String, toMany: M2.Type = M2.self, _ toName: String) {
        return relate(a: from, b: toMany, aName: fromName, bName: toName, fromMany: true, toMany: true, ordered: false)
    }

    /// Create an ordered many-to-many relation between two models. The
    /// properties on both models will be Arrays of the opposite model.
    public mutating func relate<M1: NSManagedObject, M2: NSManagedObject>(many from: M1.Type = M1.self, _ fromName: String, toManyOrdered: M2.Type = M2.self, _ toName: String) {
        return relate(a: from, b: toManyOrdered, aName: fromName, bName: toName, fromMany: true, toMany: true, ordered: true)
    }

    private mutating func relate<M1: NSManagedObject, M2: NSManagedObject>(
        a: M1.Type, b: M2.Type,
        aName: String, bName: String,
        fromMany: Bool, toMany: Bool,
        ordered: Bool
    ) {
        guard let fromEntity = self.entities[NSStringFromClass(a)], let toEntity = self.entities[NSStringFromClass(b)] else {
            fatalError("Must define entities \(a) and \(b) before relating them.")
        }
        
        let fromRelation = NSRelationshipDescription(), toRelation = NSRelationshipDescription()
        
        fromRelation.name = aName
        fromRelation.destinationEntity = toEntity
        fromRelation.deleteRule = .nullifyDeleteRule
        fromRelation.inverseRelationship = toRelation
        if (toMany) { fromRelation.minCount = 0; fromRelation.maxCount = Int.max }
        else { fromRelation.minCount = 1; fromRelation.maxCount = 1 }
        if (ordered) { fromRelation.isOrdered = true }
        
        toRelation.name = bName
        toRelation.destinationEntity = fromEntity
        toRelation.deleteRule = .nullifyDeleteRule
        toRelation.inverseRelationship = fromRelation
        if (fromMany) { toRelation.minCount = 0; toRelation.maxCount = Int.max }
        else { toRelation.minCount = 1; toRelation.maxCount = 1 }
        
        fromEntity.properties.append(fromRelation)
        toEntity.properties.append(toRelation)
    }
    
}

extension NSManagedObjectModel {
    
    /// Create a managed object model from an array of entities.
    public convenience init(entities: [NSEntityDescription]) {
        self.init()
        self.entities = entities
    }
    
    /// Create a managed object model by invoking a closure with a builder
    /// helper object used to define the entities and their relationships.
    public convenience init(builder: (inout ManagedObjectModelBuilder) -> Void) {
        var mbuilder = ManagedObjectModelBuilder()
        builder(&mbuilder)
        self.init(entities: Array(mbuilder.entities.values))
    }

}
