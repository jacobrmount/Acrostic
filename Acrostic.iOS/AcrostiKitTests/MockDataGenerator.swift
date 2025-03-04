/*/ AcrostiKit/MockDataGenerator.swift
import Foundation
import CoreData

class MockDataGenerator {
    let container: NSPersistentContainer
    
    init(container: NSPersistentContainer) {
        self.container = container
    }
    
    // Generate a set of test tokens
    func generateTestTokens(count: Int = 5) {
        let context = container.viewContext
        
        for i in 1...count {
            let token = NSEntityDescription.insertNewObject(forEntityName: "TokenEntity", into: context) as! TokenEntity
            token.id = UUID()
            token.name = "Test Token \(i)"
            token.connectionStatus = Bool.random()
            token.isActivated = Bool.random()
            token.workspaceID = "workspace_\(UUID().uuidString)"
            token.workspaceName = "Test Workspace \(i)"
            token.lastValidated = Date()
        }
        
        do {
            try context.save()
        } catch {
            print("Error generating test tokens: \(error)")
        }
    }
    
    // Generate test databases
    func generateTestDatabases(count: Int = 3, linkedToTokens: Bool = true) {
        let context = container.viewContext
        
        // If linking to tokens, fetch available tokens
        var tokens: [TokenEntity] = []
        if linkedToTokens {
            let fetchRequest: NSFetchRequest<TokenEntity> = TokenEntity.fetchRequest()
            do {
                tokens = try context.fetch(fetchRequest)
                if tokens.isEmpty {
                    print("No tokens available for linking. Generate tokens first.")
                }
            } catch {
                print("Error fetching tokens: \(error)")
            }
        }
        
        for i in 1...count {
            let database = NSEntityDescription.insertNewObject(forEntityName: "DatabaseEntity", into: context) as! DatabaseEntity
            database.id = UUID().uuidString
            database.title = "Test Database \(i)"
            database.createdTime = Date().addingTimeInterval(-Double.random(in: 100000...500000))
            database.lastEditedTime = Date().addingTimeInterval(-Double.random(in: 0...50000))
            database.lastSyncTiime = Date()
            database.url = "https://notion.so/\(UUID().uuidString)"
            database.widgetEnabled = Bool.random()
            
            // Link to a random token if available
            if !tokens.isEmpty && linkedToTokens {
                let randomToken = tokens[Int.random(in: 0..<tokens.count)]
                database.token = randomToken
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Error generating test databases: \(error)")
        }
    }
}
*/
