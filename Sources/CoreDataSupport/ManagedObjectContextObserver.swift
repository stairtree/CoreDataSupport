//
//  File.swift
//  CoreDataSupport
//
//  Created by Thomas Krajacic on 25.09.16.
//  Copyright © 2016 Thomas Krajacic. All rights reserved.
//

import Foundation
import CoreData


public final class ManagedObjectContextObserver {
    public enum ChangeType {
        case didChange(ObjectsDidChangeNotification)
        case willSave(ContextWillSaveNotification)
        case didSave(ContextDidSaveNotification)
    }
    
    public init?(moc: NSManagedObjectContext, changeHandler: @escaping (ChangeType) -> ()) {
        contextdidChangeToken = moc.addObjectsDidChangeNotificationObserver { note in
            changeHandler(.didChange(note))
        }
        contextwillSaveToken = moc.addContextWillSaveNotificationObserver { note in
            changeHandler(.willSave(note))
        }
        contextdidSaveToken = moc.addContextDidSaveNotificationObserver { note in
            changeHandler(.didSave(note))
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(contextdidChangeToken as Any)
        NotificationCenter.default.removeObserver(contextwillSaveToken as Any)
        NotificationCenter.default.removeObserver(contextdidSaveToken as Any)
    }
    
    // MARK: Private
    
    fileprivate var contextdidChangeToken : NSObjectProtocol!
    fileprivate var contextwillSaveToken : NSObjectProtocol!
    fileprivate var contextdidSaveToken : NSObjectProtocol!
    
}
