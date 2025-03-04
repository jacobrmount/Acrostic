// NactionsWidgets/Models/SharedWidgetModels.swift
import WidgetKit
import Foundation
import NactionsKit

// MARK: - Shared Widget Entry Models
struct TaskEntry: TimelineEntry {
    let date: Date
    let configuration: TaskWidgetConfigurationIntent
    let tasks: [NactionsKit.TaskItem]
    let error: String?
    
    // Add debug info to help diagnose issues
    var debugInfo: String {
        var info = ""
        
        if let database = configuration.databaseID {
            info += "Database: \(database.name) (ID: \(database.id))\n"
            info += "Token ID: \(database.tokenID.uuidString)\n"
        } else {
            info += "No database selected\n"
        }
        
        info += "Show completed: \(configuration.showCompleted)\n"
        info += "Tasks count: \(tasks.count)\n"
        
        if let error = error {
            info += "Error: \(error)\n"
        }
        
        return info
    }
}

struct ProgressEntry: TimelineEntry {
    let date: Date
    let configuration: ProgressWidgetConfigurationIntent
    let progress: NactionsKit.ProgressData
    let error: String?
    
    // Add debug info to help diagnose issues
    var debugInfo: String {
        var info = ""
        
        if let tokenID = configuration.tokenID {
            info += "Token ID: \(tokenID)\n"
        } else {
            info += "No token selected\n"
        }
        
        if let databaseID = configuration.databaseID {
            info += "Database ID: \(databaseID)\n"
        } else {
            info += "No database selected\n"
        }
        
        info += "Title: \(configuration.title)\n"
        info += "Current Value: \(progress.currentValue)\n"
        info += "Target Value: \(progress.targetValue)\n"
        info += "Percentage: \(Int(progress.percentComplete * 100))%\n"
        
        if let error = error {
            info += "Error: \(error)\n"
        }
        
        return info
    }
}
