//
//  Entity+CoreDataProperties.swift
//  VideoEdit
//
//  Created by 현은백 on 10/7/24.
//
//

import Foundation
import CoreData


extension Entity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Entity> {
        return NSFetchRequest<Entity>(entityName: "Entity")
    }

    @NSManaged public var assetURL: String?
    @NSManaged public var duration: Double

}

extension Entity : Identifiable {}
