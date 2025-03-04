// NactionsWidgets/Intents/WidgetConfigurationIntents.swift
import WidgetKit
import AppIntents
import SwiftUI

// MARK: - Database Entity for Selection
struct DatabaseEntityIntent: AppEntity {
    var id: String
    var name: String
    var tokenID: UUID
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Notion Database")
    static var defaultQuery = DatabaseQueryIntent()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct DatabaseQueryIntent: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DatabaseEntityIntent] {
        guard let userDefaults = UserDefaults(suiteName: "group.com.nactions") else {
            print("❌ Could not access UserDefaults for app group")
            return []
        }
        
        // Get all selected databases from all tokens
        var selectedDatabases: [DatabaseEntityIntent] = []
        
        for identifier in identifiers {
            // Search all tokens for this database ID
            if let dbData = findDatabaseInUserDefaults(userDefaults: userDefaults, databaseID: identifier) {
                selectedDatabases.append(dbData)
            }
        }
        
        return selectedDatabases
    }
    
    func suggestedEntities() async throws -> [DatabaseEntityIntent] {
        guard let userDefaults = UserDefaults(suiteName: "group.com.nactions") else {
            print("❌ Could not access UserDefaults for app group in suggestedEntities")
            return []
        }
        
        // Get all tokens
        guard let tokenDataArray = userDefaults.array(forKey: "nactions_tokens") as? [[String: Any]] else {
            print("❌ No tokens found in UserDefaults")
            return []
        }
        
        var availableDatabases: [DatabaseEntityIntent] = []
        
        // For each token, fetch its databases
        for tokenData in tokenDataArray {
            guard let tokenID = tokenData["id"] as? String,
                  let uuid = UUID(uuidString: tokenID) else {
                continue
            }
            
            // Get all databases for this token
            let key = "nactions_databases_\(tokenID)"
            guard let databasesData = userDefaults.array(forKey: key) as? [[String: Any]] else {
                continue
            }
            
            for db in databasesData {
                guard let dbID = db["id"] as? String,
                      let title = db["title"] as? String else {
                    continue
                }
                
                let isSelected = (db["widgetEnabled"] as? Bool) ?? false
                
                // Only include widget-enabled databases for better user experience
                if isSelected {
                    availableDatabases.append(DatabaseEntityIntent(id: dbID, name: title, tokenID: uuid))
                }
            }
        }
        
        // If no widgets are enabled, show all databases
        if availableDatabases.isEmpty {
            for tokenData in tokenDataArray {
                guard let tokenID = tokenData["id"] as? String,
                      let uuid = UUID(uuidString: tokenID) else {
                    continue
                }
                
                // Get all databases for this token
                let key = "nactions_databases_\(tokenID)"
                guard let databasesData = userDefaults.array(forKey: key) as? [[String: Any]] else {
                    continue
                }
                
                for db in databasesData {
                    guard let dbID = db["id"] as? String,
                          let title = db["title"] as? String else {
                        continue
                    }
                    
                    availableDatabases.append(DatabaseEntityIntent(id: dbID, name: title, tokenID: uuid))
                }
            }
        }
        
        return availableDatabases
    }
    
    // Helper to find database data by ID
    private func findDatabaseInUserDefaults(userDefaults: UserDefaults, databaseID: String) -> DatabaseEntityIntent? {
        // Get all tokens
        guard let tokenDataArray = userDefaults.array(forKey: "nactions_tokens") as? [[String: Any]] else {
            return nil
        }
        
        // Search each token's databases
        for tokenData in tokenDataArray {
            guard let tokenID = tokenData["id"] as? String,
                  let uuid = UUID(uuidString: tokenID) else {
                continue
            }
            
            // Get all databases for this token
            let key = "nactions_databases_\(tokenID)"
            guard let databasesData = userDefaults.array(forKey: key) as? [[String: Any]] else {
                continue
            }
            
            // Find matching database
            if let db = databasesData.first(where: { ($0["id"] as? String) == databaseID }) {
                guard let title = db["title"] as? String else {
                    continue
                }
                
                return DatabaseEntityIntent(id: databaseID, name: title, tokenID: uuid)
            }
        }
        
        return nil
    }
}

// MARK: - Task Widget Configuration
struct TaskWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Task List Configuration"
    static var description: IntentDescription = IntentDescription("Configure the task list widget")
    
    // Use DatabaseEntityIntent instead of DatabaseEntity to avoid ambiguity
    @Parameter(title: "Database")
    var databaseID: DatabaseEntityIntent?
    
    @Parameter(title: "Show Completed Tasks", default: false)
    var showCompleted: Bool
}

// MARK: - Progress Widget Configuration
struct ProgressWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Progress Widget Configuration"
    static var description: IntentDescription = IntentDescription("Configure the progress widget")
    
    @Parameter(title: "Token")
    var tokenID: String?
    
    @Parameter(title: "Database")
    var databaseID: String?
    
    @Parameter(title: "Title", default: "Progress")
    var title: String
    
    @Parameter(title: "Property for Current Value")
    var currentValueProperty: String?
    
    @Parameter(title: "Property for Target Value")
    var targetValueProperty: String?
    
    @Parameter(title: "Use Percentage", default: true)
    var usePercentage: Bool
}
