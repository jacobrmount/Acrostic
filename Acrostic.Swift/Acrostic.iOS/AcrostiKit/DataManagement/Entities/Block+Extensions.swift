// DataManagement/Entities/Block+Extensions.swift
import Foundation
import CoreData

extension BlockEntity {
    /// Converts this managed object to a NotionBlock model for API operations
    func toNotionBlock() -> NotionBlock {
        // Create a parent object for the block
        let parent = NotionBlockParent(
            type: "page_id",
            pageID: self.page?.id
        )
        
        // Create a JSONAny wrapper for the block content
        // This requires deserialization from stored binary data
        var content: JSONAny? = nil
        if let blockContentData = self.blockContent {
            if let jsonObject = try? JSONSerialization.jsonObject(with: blockContentData, options: []) {
                content = JSONAny(jsonObject)
            }
        }
        
        return NotionBlock(
            object: "block",
            id: self.id ?? "",
            parent: parent,
            createdTime: self.createdTime,
            lastEditedTime: self.lastEditedTime,
            createdBy: nil, // We don't store creator info
            lastEditedBy: nil, // We don't store editor info
            hasChildren: self.hasChildren,
            archived: self.archived,
            type: self.type ?? "",
            blockContent: content
        )
    }
    
    /// Updates this managed object from a NotionBlock model
    func update(from block: NotionBlock) {
        self.id = block.id
        self.createdTime = block.createdTime
        self.lastEditedTime = block.lastEditedTime
        self.hasChildren = block.hasChildren
        self.archived = block.archived
        self.type = block.type
        
        // Serialize block content to binary data
        if let blockContent = block.blockContent?.value {
            do {
                let data = try JSONSerialization.data(withJSONObject: blockContent, options: [])
                self.blockContent = data
            } catch {
                print("Error serializing block content: \(error)")
            }
        }
    }
    
    /// Creates a new Block managed object from a NotionBlock model
    static func create(from block: NotionBlock, in context: NSManagedObjectContext) -> BlockEntity {
        let newBlock = BlockEntity(context: context)
        newBlock.id = block.id
        newBlock.createdTime = block.createdTime
        newBlock.lastEditedTime = block.lastEditedTime
        newBlock.hasChildren = block.hasChildren
        newBlock.archived = block.archived
        newBlock.type = block.type
        
        // Serialize block content to binary data
        if let blockContent = block.blockContent?.value {
            do {
                let data = try JSONSerialization.data(withJSONObject: blockContent, options: [])
                newBlock.blockContent = data
            } catch {
                print("Error serializing block content: \(error)")
            }
        }
        
        // Connect to parent page if available
        if let parent = block.parent {
            if parent.type == "page_id", let pageID = parent.pageID {
                let pageFetch = NSFetchRequest<PageEntity>(entityName: "PageEntity")
                pageFetch.predicate = NSPredicate(format: "id == %@", pageID)
                do {
                    if let page = try context.fetch(pageFetch).first {
                        newBlock.page = page
                    }
                } catch {
                    print("Error linking block to page: \(error)")
                }
            }
        }
        
        return newBlock
    }
}
