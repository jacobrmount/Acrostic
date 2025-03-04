// NactionsKit/DataManagement/Entities/BlockEntity.swift
import Foundation
import CoreData

@objc(BlockEntity)
public class BlockEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var createdTime: Date?
    @NSManaged public var lastEditedTime: Date?
    @NSManaged public var hasChildren: Bool
    @NSManaged public var archived: Bool
    @NSManaged public var type: String?
    @NSManaged public var blockContent: Data?
    @NSManaged public var page: PageEntity?
}

// Add BlockEntity to fetch request extension
extension BlockEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BlockEntity> {
        return NSFetchRequest<BlockEntity>(entityName: "BlockEntity")
    }
}
