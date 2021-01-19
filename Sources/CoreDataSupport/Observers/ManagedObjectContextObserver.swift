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

public final class ManagedObjectContextObserver {
    public enum ChangeType {
        case didChange(ObjectsDidChangeNotification)
        case willSave(ContextWillSaveNotification)
        case didSave(ContextDidSaveNotification)
        case didSaveObjectIDs(ContextDidSaveObjectIDsNotification)
    }
    
    private let notificationCenter: NotificationCenter
    
    public init(moc: NSManagedObjectContext, notificationCenter nc: NotificationCenter = .default, changeHandler: @escaping (ChangeType) -> ()) {
        self.notificationCenter = nc
        contextdidChangeToken = moc.addObjectsDidChangeNotificationObserver(to: nc) { note in
            changeHandler(.didChange(note))
        }
        contextwillSaveToken = moc.addContextWillSaveNotificationObserver(to: nc) { note in
            changeHandler(.willSave(note))
        }
        contextdidSaveToken = moc.addContextDidSaveNotificationObserver(to: nc) { note in
            changeHandler(.didSave(note))
        }
        contextdidSaveObjectIDsToken = moc.addContextDidSaveObjectIDsNotificationObserver(to: nc) { note in
            changeHandler(.didSaveObjectIDs(note))
        }
    }
    
    deinit {
        contextdidChangeToken.map { notificationCenter.removeObserver($0) }
        contextwillSaveToken.map { notificationCenter.removeObserver($0) }
        contextdidSaveToken.map { notificationCenter.removeObserver($0) }
        contextdidSaveObjectIDsToken.map { notificationCenter.removeObserver($0) }
    }
    
    // MARK: Private
    
    fileprivate var contextdidChangeToken : NSObjectProtocol!
    fileprivate var contextwillSaveToken : NSObjectProtocol!
    fileprivate var contextdidSaveToken : NSObjectProtocol!
    fileprivate var contextdidSaveObjectIDsToken : NSObjectProtocol!

}
