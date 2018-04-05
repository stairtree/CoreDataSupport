//
//  KeyCodable.swift
//  Moody
//
//  Created by Florian on 17/11/15.
//  Copyright © 2015 objc.io. All rights reserved.
//

import CoreData


public protocol KeyCodable {
    associatedtype Keys: RawRepresentable
}

// TODO: Could be an extension on Dictionary to use Keys as key
extension KeyCodable where Keys.RawValue == String {
    public func key(_ key: Keys) -> String {
        return key.rawValue
    }
}



