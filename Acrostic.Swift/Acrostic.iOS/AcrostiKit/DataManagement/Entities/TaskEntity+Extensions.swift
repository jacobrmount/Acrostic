// NactionsKit/DataManagement/Entities/TaskEntity+Extensions.swift
import Foundation
import CoreData

public extension TaskEntity {
    // Convert to TaskItem for widget display
    func toTaskItem() -> TaskItem {
        return TaskItem(
            id: self.id ?? "",
            title: self.title ?? "Untitled Task",
            isCompleted: self.isCompleted,
            dueDate: self.dueDate
        )
    }
    
    // Update from a TaskItem
    func update(from taskItem: TaskItem) {
        self.id = taskItem.id
        self.title = taskItem.title
        self.isCompleted = taskItem.isCompleted
        self.dueDate = taskItem.dueDate
        self.lastSyncTime = Date()
    }
    
    // Create a new Task managed object from a TaskItem
    static func create(from taskItem: TaskItem,
                      databaseID: String,
                      pageID: String,
                      tokenID: UUID,
                      in context: NSManagedObjectContext) -> TaskEntity {
        let newTask = TaskEntity(context: context)
        newTask.id = taskItem.id
        newTask.title = taskItem.title
        newTask.isCompleted = taskItem.isCompleted
        newTask.dueDate = taskItem.dueDate
        newTask.pageID = pageID
        newTask.databaseID = databaseID
        newTask.tokenID = tokenID
        newTask.lastSyncTime = Date()
        return newTask
    }
}
