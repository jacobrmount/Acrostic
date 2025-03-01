// NactionsKit/BusinessLogic/DatabaseService.swift
import Foundation
import Combine
import CoreData

public struct DatabaseGroup: Identifiable {
    public let id: UUID
    public let tokenName: String
    public let tokenID: UUID
    public let databases: [DatabaseViewModelInternal]
    
    public init(id: UUID, tokenName: String, tokenID: UUID, databases: [DatabaseViewModelInternal]) {
        self.id = id
        self.tokenName = tokenName
        self.tokenID = tokenID
        self.databases = databases
    }
}

public class DatabaseService: ObservableObject {
    @Published public var databaseGroups: [DatabaseGroup] = []
    @Published public var errorMessage: String? = nil
    @Published public var isLoading: Bool = false
    
    public static let shared = DatabaseService()
    
    private init() {}
    
    // Fixed section of refreshDatabases method
    public func refreshDatabases() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let activeTokens = TokenService.shared.activatedTokens
        
        // Create a local variable to collect groups
        var collectedGroups: [DatabaseGroup] = []
        
        for token in activeTokens {
            do {
                let client = token.createAPIClient()
                let filter = NotionSearchFilter()
                filter.property = "object"
                filter.value = "database"
                
                let searchResults = try await client.searchByTitle(filter: filter, pageSize: 100)
                var databases: [NotionDatabase] = []
                
                for result in searchResults.results where result.object == "database" {
                    do {
                        let database = try await client.retrieveDatabase(databaseID: result.id)
                        databases.append(database)
                    } catch {
                        print("Error fetching database \(result.id): \(error)")
                    }
                }
                
                // Save to model - but ignore the return value to avoid warning
                _ = await saveDatabases(databases, token: token)
                
                // Create view models
                let viewModels = databases.map { db -> DatabaseViewModelInternal in
                    let isSelected = isSelected(dbID: db.id)
                    return DatabaseViewModelInternal(
                        id: db.id,
                        title: db.title?.first?.plainText ?? "Untitled",
                        tokenID: token.id,
                        tokenName: token.name,
                        isSelected: isSelected,
                        lastUpdated: db.lastEditedTime ?? Date()
                    )
                }
                
                let group = DatabaseGroup(
                    id: UUID(),
                    tokenName: token.name,
                    tokenID: token.id,
                    databases: viewModels
                )
                
                // Copy the group to our local array
                collectedGroups.append(group)
            } catch {
                await MainActor.run {
                    errorMessage = "Error fetching databases: \(error.localizedDescription)"
                }
            }
        }
        
        // Update @Published property only on MainActor with the collected data
        let groups = collectedGroups
        await MainActor.run {
            databaseGroups = groups
            isLoading = false
        }
    }
    
    private func saveDatabases(_ databases: [NotionDatabase], token: NotionToken) async -> [DatabaseEntity] {
        var savedEntities: [DatabaseEntity] = []
        let context = CoreDataStack.shared.viewContext
        
        // Find the token entity
        let tokenRequest = NSFetchRequest<TokenEntity>(entityName: "TokenEntity")
        tokenRequest.predicate = NSPredicate(format: "id == %@", token.id as CVarArg)
        
        do {
            let tokenEntities = try context.fetch(tokenRequest)
            guard let tokenEntity = tokenEntities.first else {
                print("Token entity not found for \(token.id)")
                return []
            }
            
            for database in databases {
                // Check if database already exists
                let dbRequest = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
                dbRequest.predicate = NSPredicate(format: "id == %@", database.id)
                
                let existingDatabases = try context.fetch(dbRequest)
                let dbEntity: DatabaseEntity
                
                if let existingDb = existingDatabases.first {
                    // Update existing database
                    dbEntity = existingDb
                    dbEntity.update(from: database)
                } else {
                    // Create new database
                    dbEntity = DatabaseEntity(context: context)
                    dbEntity.id = database.id
                    dbEntity.title = database.title?.first?.plainText ?? "Untitled"
                    dbEntity.databaseDescription = database.description?.first?.plainText
                    dbEntity.createdTime = database.createdTime
                    dbEntity.lastEditedTime = database.lastEditedTime
                    dbEntity.url = database.url
                    dbEntity.lastSyncTiime = Date() // Using lastSyncTiime instead of lastSyncTime
                    dbEntity.widgetEnabled = false
                    dbEntity.token = tokenEntity
                }
                
                savedEntities.append(dbEntity)
            }
            
            try context.save()
        } catch {
            print("Error saving databases: \(error)")
        }
        
        return savedEntities
    }
    
    private func isSelected(dbID: String) -> Bool {
        // Check if the database is selected for widget display
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.predicate = NSPredicate(format: "id == %@ AND widgetEnabled == YES", dbID)
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("Error checking database selection: \(error)")
            return false
        }
    }
    
    public func toggleDatabaseSelection(databaseID: String, tokenID: UUID) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.predicate = NSPredicate(format: "id == %@", databaseID)
        
        do {
            if let database = try context.fetch(request).first {
                // Toggle selection
                database.widgetEnabled = !database.widgetEnabled
                try context.save()
                
                // Update UI
                for i in 0..<databaseGroups.count {
                    if databaseGroups[i].tokenID == tokenID {
                        var updatedDatabases = databaseGroups[i].databases
                        if let index = updatedDatabases.firstIndex(where: { $0.id == databaseID }) {
                            updatedDatabases[index] = DatabaseViewModelInternal(
                                id: updatedDatabases[index].id,
                                title: updatedDatabases[index].title,
                                tokenID: updatedDatabases[index].tokenID,
                                tokenName: updatedDatabases[index].tokenName,
                                isSelected: database.widgetEnabled,
                                lastUpdated: updatedDatabases[index].lastUpdated
                            )
                        }
                        
                        let updatedGroup = DatabaseGroup(
                            id: databaseGroups[i].id,
                            tokenName: databaseGroups[i].tokenName,
                            tokenID: databaseGroups[i].tokenID,
                            databases: updatedDatabases
                        )
                        
                        DispatchQueue.main.async {
                            // Update the group in our array
                            var updatedGroups = self.databaseGroups
                            updatedGroups[i] = updatedGroup
                            self.databaseGroups = updatedGroups
                            
                            // Notify observers
                            self.objectWillChange.send()
                        }
                    }
                }
            }
        } catch {
            print("Error toggling database selection: \(error)")
        }
    }
}
