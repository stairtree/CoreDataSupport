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
    
    private let contextdidChangeToken : NSObjectProtocol
    private let contextwillSaveToken : NSObjectProtocol
    private let contextdidSaveToken : NSObjectProtocol
    private let contextdidSaveObjectIDsToken : NSObjectProtocol
    
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
        notificationCenter.removeObserver(contextdidChangeToken)
        notificationCenter.removeObserver(contextwillSaveToken)
        notificationCenter.removeObserver(contextdidSaveToken)
        notificationCenter.removeObserver(contextdidSaveObjectIDsToken)
    }
}
