// AcrosticWidgets/Intents/WidgetConfigurationIntents.swift
import WidgetKit
import AppIntents
import SwiftUI
import AcrostiKit

// MARK: - Database for Selection
struct DatabaseIntent: AppEntity {
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
    func entities(for identifiers: [String]) async throws -> [DatabaseIntent] {
        guard let defaults = UserDefaults(suiteName: AppGroupConfig.appGroupIdentifier) else {
            print("❌ Could not access UserDefaults for app group")
            return []
        }
        
        // Get all selected databases from all tokens
        var selectedDatabases: [DatabaseIntent] = []
        
        for identifier in identifiers {
            // Search all tokens for this database ID
            if let dbData = findDatabaseInUserDefaults(userDefaults: defaults, databaseID: identifier) {
                selectedDatabases.append(dbData)
            }
        }
        
        return selectedDatabases
    }
    
    func suggestedEntities() async throws -> [DatabaseIntent] {
        guard let userDefaults = UserDefaults(suiteName: AppGroupConfig.appGroupIdentifier) else {
            print("❌ Could not access UserDefaults for app group in suggestedEntities")
            return []
        }
        
        // Get all tokens
        guard let tokenDataArray = userDefaults.array(forKey: "acrostic_tokens") as? [[String: Any]] else {
            print("❌ No tokens found in UserDefaults")
            return []
        }
        
        var availableDatabases: [DatabaseIntent] = []
        
        // For each token, fetch its databases
        for tokenData in tokenDataArray {
            guard let tokenID = tokenData["id"] as? String,
                  let isActive = tokenData["isActivated"] as? Bool,
                  isActive else {
                continue
            }
            
            let uuid = UUID(uuidString: tokenID) ?? UUID()
            
            // Get all databases for this token
            let key = "acrostic_databases_\(tokenID)"
            guard let databasesData = userDefaults.array(forKey: key) as? [[String: Any]] else {
                print("⚠️ No databases found for token \(tokenID)")
                continue
            }
            
            print("📊 Found \(databasesData.count) databases for token \(tokenID)")
            
            for db in databasesData {
                guard let dbID = db["id"] as? String,
                      let title = db["title"] as? String else {
                    continue
                }
                
                // Include all databases, not just widget-enabled ones
                availableDatabases.append(DatabaseIntent(id: dbID, name: title, tokenID: uuid))
                print("✅ Added database: \(title) (\(dbID))")
            }
        }
        
        return availableDatabases
    }
    
    // Helper to find database data by ID
    private func findDatabaseInUserDefaults(userDefaults: UserDefaults, databaseID: String) -> DatabaseIntent? {
        // Get all tokens
        guard let tokenDataArray = userDefaults.array(forKey: "acrostic_tokens") as? [[String: Any]] else {
            return nil
        }
        
        // Search each token's databases
        for tokenData in tokenDataArray {
            guard let tokenID = tokenData["id"] as? String,
                  let uuid = UUID(uuidString: tokenID) else {
                continue
            }
            
            // Get all databases for this token
            let key = "acrostic_databases_\(tokenID)"
            guard let databasesData = userDefaults.array(forKey: key) as? [[String: Any]] else {
                continue
            }
            
            // Find matching database
            if let db = databasesData.first(where: { ($0["id"] as? String) == databaseID }) {
                guard let title = db["title"] as? String else {
                    continue
                }
                
                return DatabaseIntent(id: databaseID, name: title, tokenID: uuid)
            }
        }
        
        return nil
    }
}

// MARK: - Task Widget Configuration
struct TaskWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Task List Configuration"
    static var description: IntentDescription = IntentDescription("Configure the task list widget")
    
    // Add the following method:
    static var presetRecommendations: [TaskWidgetConfigurationIntent] {
        // Trigger data refresh
        let appGroupID = "group.com.acrostic"
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(Date().timeIntervalSince1970, forKey: "widget_config_refresh_timestamp")
            defaults.synchronize()
        }
        
        // Return default recommendations
        let intent = TaskWidgetConfigurationIntent()
        intent.showCompleted = false
        return [intent]
    }
    
    @Parameter(title: "Database")
    var databaseID: DatabaseIntent?
    
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
