// NactionsKit/NactionsKit.swift
import Foundation

// MARK: - Widget Data Models

/// Task data model for widget display
public struct TaskItem: Identifiable, Hashable, Codable {
    public let id: String
    public let title: String
    public let isCompleted: Bool
    public let dueDate: Date?
    
    public init(id: String, title: String, isCompleted: Bool, dueDate: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
    }
    
    // Used for previews and placeholders
    public static var samples: [TaskItem] {
        [
            TaskItem(id: "1", title: "Review project proposal", isCompleted: false, dueDate: Date.now.addingTimeInterval(86400)),
            TaskItem(id: "2", title: "Update documentation", isCompleted: true, dueDate: Date.now),
            TaskItem(id: "3", title: "Prepare for demo", isCompleted: false, dueDate: Date.now.addingTimeInterval(172800)),
            TaskItem(id: "4", title: "Send weekly report", isCompleted: false, dueDate: Date.now.addingTimeInterval(43200))
        ]
    }
}

/// Progress data model for widget display
public struct ProgressData: Codable {
    public let title: String
    public let currentValue: Double
    public let targetValue: Double
    public let percentComplete: Double
    
    public init(title: String, currentValue: Double, targetValue: Double) {
        self.title = title
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.percentComplete = targetValue > 0 ? min(1.0, currentValue / targetValue) : 0.0
    }
    
    // Used for previews and placeholders
    public static var sample: ProgressData {
        ProgressData(title: "Project Completion", currentValue: 65, targetValue: 100)
    }
}

/// Cached data
public struct CachedData<T: Codable>: Codable {
    public let timestamp: Date
    public let data: T
    
    public init(timestamp: Date, data: T) {
        self.timestamp = timestamp
        self.data = data
    }
}

/// Custom errors for widget operations
public enum WidgetError: Error {
    case tokenNotFound
    case databaseNotFound
    case apiError(String)
    case decodingError
    
    public var localizedDescription: String {
        switch self {
        case .tokenNotFound:
            return "Token not found. Please reconfigure the widget."
        case .databaseNotFound:
            return "Database not found. Please check your configuration."
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError:
            return "Failed to decode response from Notion."
        }
    }
}
