//
//  KeyCodable+ManagedObject.swift
//  Moody
//
//  Created by Florian on 17/11/15.
//  Copyright © 2015 objc.io. All rights reserved.
//

import CoreData


extension KeyCodable where Self: NSManagedObject, Keys.RawValue == String {
    public func willAccessValueForKey(_ key: Keys) {
        willAccessValue(forKey: key.rawValue)
    }

    public func didAccessValueForKey(_ key: Keys) {
        didAccessValue(forKey: key.rawValue)
    }

    public func willChangeValueForKey(_ key: Keys) {
        (self as NSManagedObject).willChangeValue(forKey: key.rawValue)
    }

    public func didChangeValueForKey(_ key: Keys) {
        (self as NSManagedObject).didChangeValue(forKey: key.rawValue)
    }

    public func valueForKey(_ key: Keys) -> AnyObject? {
        return (self as NSManagedObject).value(forKey: key.rawValue) as AnyObject?
    }

    public func mutableSetValueForKey(_ key: Keys) -> NSMutableSet {
        return mutableSetValue(forKey: key.rawValue)
    }

    public func changedValueForKey(_ key: Keys) -> AnyObject? {
        return changedValues()[key.rawValue] as AnyObject?
    }

    public func committedValueForKey(_ key: Keys) -> AnyObject? {
        return committedValues(forKeys: [key.rawValue])[key.rawValue] as AnyObject?
    }
}
