// NactionsWidgets/Extensions/UserDefaultsExtension.swift
import Foundation
import NactionsKit

extension UserDefaults {
    // MARK: - Task Data
    
    /// Gets cached tasks for a specific token and database
    func getCachedTasks(tokenID: String, databaseID: String) -> [NactionsKit.TaskItem]? {
        let key = "nactions_tasks_\(tokenID)_\(databaseID)"
        
        guard let cacheData = self.dictionary(forKey: key) else {
            return nil
        }
        
        // Check if cache has expired (1 hour)
        guard let timestamp = cacheData["timestamp"] as? TimeInterval,
              Date().timeIntervalSince1970 - timestamp <= 3600 else {
            return nil
        }
        
        guard let taskDicts = cacheData["tasks"] as? [[String: Any]] else {
            return nil
        }
        
        return taskDicts.compactMap { dict -> NactionsKit.TaskItem? in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let isCompleted = dict["isCompleted"] as? Bool else {
                return nil
            }
            
            let dueDate: Date?
            if let timestamp = dict["dueDate"] as? TimeInterval {
                dueDate = Date(timeIntervalSince1970: timestamp)
            } else {
                dueDate = nil
            }
            
            return NactionsKit.TaskItem(id: id, title: title, isCompleted: isCompleted, dueDate: dueDate)
        }
    }
    
    // MARK: - Progress Data
    
    /// Gets cached progress data for a specific token and database
    func getCachedProgress(tokenID: String, databaseID: String) -> NactionsKit.ProgressData? {
        let key = "nactions_progress_\(tokenID)_\(databaseID)"
        
        guard let dict = self.dictionary(forKey: key),
              let timestamp = dict["timestamp"] as? TimeInterval,
              let title = dict["title"] as? String,
              let currentValue = dict["currentValue"] as? Double,
              let targetValue = dict["targetValue"] as? Double else {
            return nil
        }
        
        // Check if cache has expired (1 hour)
        guard Date().timeIntervalSince1970 - timestamp <= 3600 else {
            return nil
        }
        
        return NactionsKit.ProgressData(title: title, currentValue: currentValue, targetValue: targetValue)
    }
}
