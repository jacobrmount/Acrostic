// AcrostiKit/Domain/Services/FileService.swift
import Foundation
import Combine
import CoreData

public class FileService: ObservableObject {
    public struct FileGroup: Identifiable {
        public let id: UUID
        public let tokenName: String
        public let tokenID: UUID
        public let files: [FileMetadata]
        
        public init(id: UUID, tokenName: String, tokenID: UUID, files: [FileMetadata]) {
            self.id = id
            self.tokenName = tokenName
            self.tokenID = tokenID
            self.files = files
        }
    }
    
    @Published public var fileGroups: [FileGroup] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    private let cacheKey = "acrostic_file_metadata_cache"
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24 hours
    
    public static let shared = FileService()
    
    private init() {}
    
    /// Loads file metadata (titles) for activated tokens only
    public func loadFileMetadata() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Get activated tokens
        let activeTokens = TokenService.shared.activatedTokens
        
        // No activated tokens? Clear and return
        if activeTokens.isEmpty {
            await MainActor.run {
                fileGroups = []
                isLoading = false
            }
            return
        }
        
        // Try to load from cache first
        let cachedData = loadCachedMetadata()
        let needsRefresh = cachedData == nil || shouldRefreshCache(cachedData!)
        
        if !needsRefresh, let groupedData = groupCachedMetadata(cachedData!, activeTokens) {
            // Use cache if valid
            let finalGroups = groupedData // create local capture to avoid Swift 6 warning
            await MainActor.run {
                fileGroups = finalGroups
                isLoading = false
            }
            
            // Optionally refresh in background if older than 1 hour
            if isOlderThanHour(cachedData!) {
                Task {
                    await refreshMetadata(for: activeTokens)
                }
            }
            return
        }
        
        // Cache not available or needs refresh - load from API
        await refreshMetadata(for: activeTokens)
    }
    
    /// Refreshes metadata for specified tokens from the API
    private func refreshMetadata(for tokens: [TokenEntity]) async {
        var allMetadata: [FileMetadata] = []
        var collectedGroups: [FileGroup] = []
        var errors: [String] = []
        
        for token in tokens {
            guard let tokenID = token.id, let apiToken = token.apiToken, !apiToken.isEmpty else {
                continue
            }
            
            do {
                let client = NotionAPIClient(token: apiToken)
                let metadata = try await client.fetchFileMetadata(forTokenID: tokenID)
                
                if !metadata.isEmpty {
                    // Store for cache
                    allMetadata.append(contentsOf: metadata)
                    
                    // Create group
                    let group = FileGroup(
                        id: UUID(),
                        tokenName: token.workspaceName ?? "Unknown",
                        tokenID: tokenID,
                        files: metadata
                    )
                    collectedGroups.append(group)
                }
            } catch {
                print("Error fetching metadata for token \(tokenID): \(error)")
                errors.append(error.localizedDescription)
            }
        }
        
        // Cache all metadata
        if !allMetadata.isEmpty {
            cacheMetadata(allMetadata)
        }
        
        // Update UI
        let finalGroups = collectedGroups
        let finalErrorMessage = errors.isEmpty ? nil : errors.joined(separator: "\n")
        
        await MainActor.run {
            fileGroups = finalGroups
            self.errorMessage = finalErrorMessage
            isLoading = false
        }
    }
    
    /// Toggle selection for a file
    public func toggleFileSelection(fileID: String, tokenID: UUID) {
        guard let groupIndex = fileGroups.firstIndex(where: { $0.tokenID == tokenID }) else {
            return
        }
        
        guard let fileIndex = fileGroups[groupIndex].files.firstIndex(where: { $0.id == fileID }) else {
            return
        }
        
        var updatedGroups = fileGroups
        var updatedFiles = updatedGroups[groupIndex].files
        
        // Toggle selection status
        let isSelected = !updatedFiles[fileIndex].isSelected
        updatedFiles[fileIndex] = FileMetadata(
            id: updatedFiles[fileIndex].id,
            title: updatedFiles[fileIndex].title,
            type: updatedFiles[fileIndex].type,
            tokenID: updatedFiles[fileIndex].tokenID,
            isSelected: isSelected
        )
        
        // Save selection to persistent storage
        saveFileSelection(fileID: fileID, isSelected: isSelected)
        
        // Update group
        updatedGroups[groupIndex] = FileGroup(
            id: updatedGroups[groupIndex].id,
            tokenName: updatedGroups[groupIndex].tokenName,
            tokenID: updatedGroups[groupIndex].tokenID,
            files: updatedFiles
        )
        
        // Update state
        fileGroups = updatedGroups

        // Refresh widget data to reflect selection
        Task {
                await AppGroupConfig.refreshWidgetData()
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveFileSelection(fileID: String, isSelected: Bool) {
        // Simple UserDefaults-based persistence for selections
        let key = "acrostic_file_selection_\(fileID)"
        UserDefaults.standard.set(isSelected, forKey: key)
    }
    
    private func getFileSelection(fileID: String) -> Bool {
        let key = "acrostic_file_selection_\(fileID)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    private func cacheMetadata(_ metadata: [FileMetadata]) {
        guard let userDefaults = AppGroupConfig.sharedUserDefaults else { return }
        
        // Store with timestamp for validity checking
        let cacheData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "metadata": metadata.map { file -> [String: Any] in
                return [
                    "id": file.id,
                    "title": file.title,
                    "type": file.type == .database ? "database" : "page",
                    "tokenID": file.tokenID.uuidString,
                    "isSelected": getFileSelection(fileID: file.id)
                ]
            }
        ]
        
        userDefaults.set(cacheData, forKey: cacheKey)
        userDefaults.synchronize()
    }
    
    private func loadCachedMetadata() -> [FileMetadata]? {
        guard let userDefaults = AppGroupConfig.sharedUserDefaults,
              let cacheData = userDefaults.dictionary(forKey: cacheKey),
              let metadataArray = cacheData["metadata"] as? [[String: Any]] else {
            return nil
        }
        
        return metadataArray.compactMap { dict -> FileMetadata? in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let typeString = dict["type"] as? String,
                  let tokenIDString = dict["tokenID"] as? String,
                  let tokenID = UUID(uuidString: tokenIDString) else {
                return nil
            }
            
            let type: FileType = typeString == "database" ? .database : .page
            let isSelected = getFileSelection(fileID: id)
            
            return FileMetadata(
                id: id,
                title: title,
                type: type,
                tokenID: tokenID,
                isSelected: isSelected
            )
        }
    }
    
    private func shouldRefreshCache(_ cachedMetadata: [FileMetadata]) -> Bool {
        guard let userDefaults = AppGroupConfig.sharedUserDefaults,
              let cacheData = userDefaults.dictionary(forKey: cacheKey),
              let timestamp = cacheData["timestamp"] as? TimeInterval else {
            return true
        }
        
        let cacheAge = Date().timeIntervalSince1970 - timestamp
        return cacheAge > cacheValidityDuration
    }
    
    private func isOlderThanHour(_ cachedMetadata: [FileMetadata]) -> Bool {
        guard let userDefaults = AppGroupConfig.sharedUserDefaults,
              let cacheData = userDefaults.dictionary(forKey: cacheKey),
              let timestamp = cacheData["timestamp"] as? TimeInterval else {
            return true
        }
        
        let cacheAge = Date().timeIntervalSince1970 - timestamp
        return cacheAge > 3600 // 1 hour
    }
    
    private func groupCachedMetadata(_ metadata: [FileMetadata], _ activeTokens: [TokenEntity]) -> [FileGroup]? {
        // Extract active token IDs
        let activeTokenIDs = Set(activeTokens.compactMap { $0.id })
        
        // Filter metadata for active tokens
        let filteredMetadata = metadata.filter { activeTokenIDs.contains($0.tokenID) }
        
        if filteredMetadata.isEmpty {
            return nil
        }
        
        // Group by token
        var groupedFiles: [UUID: [FileMetadata]] = [:]
        for file in filteredMetadata {
            groupedFiles[file.tokenID, default: []].append(file)
        }
        
        // Create groups
        var groups: [FileGroup] = []
        for token in activeTokens {
            guard let tokenID = token.id,
                  let files = groupedFiles[tokenID],
                  !files.isEmpty else {
                continue
            }
            
            groups.append(FileGroup(
                id: UUID(),
                tokenName: token.workspaceName ?? "Unknown",
                tokenID: tokenID,
                files: files
            ))
        }
        
        return groups
    }
}
