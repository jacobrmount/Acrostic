// BusinessLogic/NotionDataAdapter.swift
import Foundation
import CoreData

class NotionDataAdapter {
    // Convert from TokenEntity to NotionToken models
    static func convertToTokenList(_ entities: [TokenEntity]) -> [NotionToken] {
        return entities.compactMap { entity -> NotionToken? in
            guard let id = entity.id,
                  let name = entity.name,
                  let apiToken = TokenDataController.shared.getSecureToken(for: id.uuidString) else {
                return nil
            }
            
            return NotionToken(
                id: id,
                name: name,
                apiToken: apiToken,
                isConnected: entity.connectionStatus,
                isActivated: entity.isActivated,
                workspaceID: entity.workspaceID,
                workspaceName: entity.workspaceName
            )
        }
    }
    
    static func convertToDatabaseViewModelList(_ entities: [DatabaseEntity]) -> [DatabaseViewModelInternal] {
        return entities.map { $0.toDatabaseViewModel() }
    }
    
    static func convertToTaskItems(_ entities: [PageEntity]) -> [TaskItem] {
        return entities.map { $0.toTaskItem() }
    }
    
    // Utility methods for extracting data
    static func extractTitleText(_ richTextData: Any?) -> String {
        guard let richTextArray = richTextData as? [[String: Any]] else {
            return "Untitled"
        }
        
        let texts = richTextArray.compactMap { item -> String? in
            if let textObj = item["text"] as? [String: Any],
               let content = textObj["content"] as? String {
                return content
            }
            return nil
        }
        
        return texts.joined()
    }
}
