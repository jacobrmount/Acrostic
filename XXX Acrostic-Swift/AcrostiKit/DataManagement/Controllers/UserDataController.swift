// NactionsKit/DataManagement/Controllers/UserDataController.swift
import Foundation
import CoreData

public class UserDataController {
    public static let shared = UserDataController()
    
    private init() {}
    
    // Since the User entity can't be found, we'll redirect to the TokenEntity
    func fetchTokenUsers() -> [TokenEntity] {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<TokenEntity> = TokenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "connectionStatus == %@", NSNumber(value: true))
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching token users: \(error)")
            return []
        }
    }
    
    func saveToken(_ token: NotionToken) -> TokenEntity? {
        let context = CoreDataStack.shared.viewContext
        
        // Check if already exists
        let request: NSFetchRequest<TokenEntity> = TokenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", token.id as CVarArg)
        
        do {
            let existingTokens = try context.fetch(request)
            
            if let existingToken = existingTokens.first {
                // Update existing
                existingToken.name = token.name
                existingToken.apiToken = token.apiToken
                existingToken.workspaceID = token.workspaceID
                try context.save()
                return existingToken
            } else {
                // Create new
                let tokenEntity = TokenEntity.create(from: token, in: context)
                try context.save()
                return tokenEntity
            }
        } catch {
            print("Error saving token: \(error)")
            return nil
        }
    }
    
    func deleteToken(id: UUID) {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<TokenEntity> = TokenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let token = try context.fetch(request).first {
                context.delete(token)
                try context.save()
            }
        } catch {
            print("Error deleting token: \(error)")
        }
    }
}
