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

extension NSExpressionDescription {
    
    /// `NSExpressionDescription` for including the `objectID` in dictionary result types
    ///
    /// Example:
    /// ```
    /// fetchRequest.resultType = .dictionaryResultType
    /// var propertiesToFetch: [Any] = [NSExpressionDescription.objectID]
    /// propertiesToFetch.append(contentsOf: entity.properties)
    /// fetchRequest.propertiesToFetch = propertiesToFetch
    ///  ```
    public static let objectID: NSExpressionDescription = {
        let description = NSExpressionDescription()
        description.name = "objectID"
        description.expression = NSExpression.expressionForEvaluatedObject()
        description.expressionResultType = .objectIDAttributeType
        return description
    }()
}
