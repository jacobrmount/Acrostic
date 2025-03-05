// AcrostiKit/Data/Controllers/TaskController.swift
import Foundation
import CoreData

/// Manages all task-related Core Data operations
public final class TaskDataController {
    /// The shared singleton instance
    public static let shared = TaskDataController()
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetches all tasks
    public func fetchTasks() -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
        request.sortDescriptors = [
            NSSortDescriptor(key: "isCompleted", ascending: true),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching tasks: \(error)")
            return []
        }
    }
    
    /// Fetches tasks for a specific database
    public func fetchTasks(for databaseID: String) -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
        request.predicate = NSPredicate(format: "database.id == %@", databaseID)
        request.sortDescriptors = [
            NSSortDescriptor(key: "isCompleted", ascending: true),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching tasks for database \(databaseID): \(error)")
            return []
        }
    }
    
    /// Fetches tasks for a specific token
    public func fetchTasks(for tokenID: UUID) -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
        request.predicate = NSPredicate(format: "token.id == %@", tokenID as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(key: "isCompleted", ascending: true),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching tasks for token \(tokenID): \(error)")
            return []
        }
    }
    
    /// Fetches tasks as TaskItem structs for a specific database
    public func fetchTaskItems(for databaseID: String) -> [TaskItem] {
        let tasks = fetchTasks(for: databaseID)
        return tasks.compactMap { $0.toTaskItem() }
    }
    
    /// Fetches a specific task by ID
    public func fetchTask(id: String) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching task with ID \(id): \(error)")
            return nil
        }
    }
    
    // MARK: - Create/Update Operations
    
    /// Creates or updates a task from a TaskItem model
    public func saveTask(from taskItem: TaskItem, databaseID: String, pageID: String, tokenID: UUID) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
        request.predicate = NSPredicate(format: "id == %@", taskItem.id)
        
        do {
            let existingTasks = try context.fetch(request)
            
            if let existingTask = existingTasks.first {
                // Direct setValue instead of .update
                existingTask.setValue(taskItem.title, forKey: "title")
                existingTask.setValue(taskItem.isCompleted, forKey: "isCompleted")
                existingTask.setValue(taskItem.dueDate, forKey: "dueDate")
                try context.save()
                return existingTask
            } else {
                // Direct NSEntityDescription creation
                let newTask = NSEntityDescription.insertNewObject(forEntityName: "Task", into: context)
                newTask.setValue(taskItem.id, forKey: "id")
                newTask.setValue(taskItem.title, forKey: "title")
                newTask.setValue(taskItem.isCompleted, forKey: "isCompleted")
                newTask.setValue(taskItem.dueDate, forKey: "dueDate")
                newTask.setValue(databaseID, forKey: "databaseID")
                try context.save()
                return newTask
            }
        } catch {
            print("Error saving task: \(error)")
            return nil
        }
    }
    
    /// Saves multiple tasks from TaskItem structs
    public func saveTasks(from taskItems: [TaskItem], databaseID: String, tokenID: UUID) {
        let context = CoreDataStack.shared.viewContext
        
        for taskItem in taskItems {
            // Create or update task
            let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
            request.predicate = NSPredicate(format: "id == %@", taskItem.id)
            
            do {
                let existingTasks = try context.fetch(request)
                
                if let existingTask = existingTasks.first {
                    // Update existing task
                    existingTask.update(from: taskItem)
                } else {
                    // Create new task
                    _ = NSManagedObject.create(
                        from: taskItem,
                        databaseID: databaseID,
                        pageID: taskItem.id, // Assuming page ID is the same as task ID
                        tokenID: tokenID,
                        in: context
                    )
                }
            } catch {
                print("Error saving task \(taskItem.id): \(error)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving tasks batch: \(error)")
        }
    }
    
    /// Updates a task's completion status
    public func updateTaskCompletion(taskID: String, isCompleted: Bool) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
        request.predicate = NSPredicate(format: "id == %@", taskID)
        
        do {
            if let task = try context.fetch(request).first {
                task.setValue(isCompleted, forKey: "isCompleted")
                try context.save()
                print("Task completion status updated to: \(isCompleted)")
            } else {
                print("Task with ID \(taskID) not found")
            }
        } catch {
            print("Error updating task completion: \(error)")
        }
    }
    
    // MARK: - Delete Operations
    
    /// Deletes all tasks for a specific database
    public func deleteTasks(for databaseID: String) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
        request.predicate = NSPredicate(format: "database.id == %@", databaseID)
        
        do {
            let tasks = try context.fetch(request)
            for task in tasks {
                context.delete(task)
            }
            try context.save()
            print("Deleted \(tasks.count) tasks for database \(databaseID)")
        } catch {
            print("Error deleting tasks for database \(databaseID): \(error)")
        }
    }
    
    /// Deletes all tasks for a specific token
    public func deleteTasks(for tokenID: UUID) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
        request.predicate = NSPredicate(format: "token.id == %@", tokenID as CVarArg)
        
        do {
            let tasks = try context.fetch(request)
            for task in tasks {
                context.delete(task)
            }
            try context.save()
            print("Deleted \(tasks.count) tasks for token \(tokenID)")
        } catch {
            print("Error deleting tasks for token \(tokenID): \(error)")
        }
    }
    
    /// Deletes a specific task
    public func deleteTask(id: String) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Task")
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            if let task = try context.fetch(request).first {
                context.delete(task)
                try context.save()
                print("Task deleted successfully")
            } else {
                print("Task with ID \(id) not found for deletion")
            }
        } catch {
            print("Error deleting task: \(error)")
        }
    }
}
