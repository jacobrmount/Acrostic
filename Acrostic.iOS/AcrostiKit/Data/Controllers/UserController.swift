// AcrostiKit/Data/Controllers/UserController.swift
import Foundation
import CoreData

public class UserDataController {
    public static let shared = UserDataController()
    
    private init() {}
    
    func saveToken(_ token: TokenEntity) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        
        // Ensure token.id is not nil before proceeding
        guard let tokenID = token.id else {
            print("Error: token.id is nil")
            return nil
        }
        
        // Check if already exists
        let request = NSFetchRequest<NSManagedObject>(entityName: "Token")
        request.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        do {
            let existingTokens = try context.fetch(request)
            
            if let existingToken = existingTokens.first {
                // Update existing
                // Removed token.name update as TokenEntity does not have a 'name' member.
                existingToken.setValue(token.apiToken, forKey: "apiToken")
                existingToken.setValue(token.workspaceID, forKey: "workspaceID")
                existingToken.setValue(token.workspaceName, forKey: "workspaceName")
                try context.save()
                return existingToken
            } else {
                // Create new using NSManagedObject extension method
                let tokenEntity = NSManagedObject.createToken(from: token, in: context)
                try context.save()
                return tokenEntity
            }
        } catch {
            print("Error saving token: \(error)")
            return nil
        }
    }

    func fetchTokenUsers() -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Token")
        request.predicate = NSPredicate(format: "connectionStatus == %@", NSNumber(value: true))
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching token users: \(error)")
            return []
        }
    }

    func deleteToken(id: UUID) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Token")
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

