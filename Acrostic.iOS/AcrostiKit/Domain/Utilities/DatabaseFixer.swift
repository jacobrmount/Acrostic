// AcrostiKit/Utilities/DatabaseFixer.swift
import Foundation
import CoreData

public class DatabaseFixer {
    public static let shared = DatabaseFixer()
    
    private init() {}
    
    // In AcrostiKit/Domain/Utilities/DatabaseFixer.swift
    public func fixDatabaseEntities() {
        print("🔧 Running database entity fixer...")
        let context = CoreDataStack.shared.viewContext
        
        // First check for databases with nil IDs
        let nilIDRequest = NSFetchRequest<NSManagedObject>(entityName: "Database")
        nilIDRequest.predicate = NSPredicate(format: "id == nil")
        
        do {
            let badDatabases = try context.fetch(nilIDRequest)
            print("🔍 Found \(badDatabases.count) databases with nil IDs")
            
            if !badDatabases.isEmpty {
                for database in badDatabases {
                    var fallbackID: String
                    
                    // Try multiple strategies to recover the ID
                    if let url = database.value(forKey: "url") as? String, !url.isEmpty {
                        // Try extracting ID from URL
                        if let idComponent = url.components(separatedBy: "/").last, !idComponent.isEmpty {
                            fallbackID = idComponent
                            print("✅ Extracted ID from URL: \(fallbackID)")
                        } else if url.contains("15bed8dc2e838174bb19d5423c4e2ddf") {
                            // Known issue with this specific database
                            fallbackID = "15bed8dc2e838174bb19d5423c4e2ddf"
                            print("✅ Assigned known ID for database")
                        } else {
                            // Create deterministic ID from URL
                            fallbackID = String(url.hash)
                            print("✅ Generated ID hash from URL: \(fallbackID)")
                        }
                    } else if let title = database.value(forKey: "titleString") as? String, !title.isEmpty {
                        // Create deterministic ID from title
                        fallbackID = "\(title.hash)"
                        print("✅ Generated ID hash from title: \(fallbackID)")
                    } else {
                        // Last resort: random UUID
                        fallbackID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
                        print("⚠️ Generated random ID: \(fallbackID)")
                    }
                    
                    // Set the ID with direct setValue (avoiding debugSetValue which might have issues)
                    database.setValue(fallbackID, forKey: "id")
                    print("✅ Fixed database: ID=\(fallbackID)")
                    
                    // Verify ID was set
                    if database.value(forKey: "id") == nil {
                        print("❌ CRITICAL: ID is still nil after setting!")
                    }
                }
                
                // Save immediately after each fix to ensure changes are persisted
                try context.save()
                print("✅ Saved \(badDatabases.count) fixed databases")
            }
        } catch {
            print("❌ Error in fixDatabaseEntities: \(error)")
            // Try to recover from the error
            context.rollback()
        }
        
        // Now check for duplicate databases
        print("🔍 Checking for duplicate databases...")
        let allDatabasesRequest = NSFetchRequest<NSManagedObject>(entityName: "Database")
        
        do {
            let allDatabases = try context.fetch(allDatabasesRequest)
            var seenIDs = [String: NSManagedObject]()
            var duplicates = [NSManagedObject]()
            
            for database in allDatabases {
                if let id = database.value(forKey: "id") as? String {
                    if seenIDs[id] != nil {
                        // This is a duplicate
                        duplicates.append(database)
                    } else {
                        seenIDs[id] = database
                    }
                }
            }
            
            if !duplicates.isEmpty {
                print("🗑 Removing \(duplicates.count) duplicate databases")
                for duplicate in duplicates {
                    context.delete(duplicate)
                }
                try context.save()
                print("✅ Removed duplicate databases")
            } else {
                print("✅ No duplicate databases found")
            }
        } catch {
            print("❌ Error checking for duplicate databases: \(error)")
        }
    }
}
