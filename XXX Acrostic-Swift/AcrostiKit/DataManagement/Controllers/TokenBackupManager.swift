// DataManagement/Controllers/TokenBackupManager.swift
import SwiftUI
import UniformTypeIdentifiers
import UIKit

public final class TokenBackupManager {
    
    // MARK: - Export Tokens
    
    public static func exportTokens(completion: @escaping (Bool) -> Void) {
        // Fetch tokens from Core Data
        let tokens = TokenDataController.shared.fetchTokens()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(tokens)
            // Write JSON data to a temporary file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("NotionTokens.json")
            try jsonData.write(to: tempURL)
            exportTokens(from: tempURL, completion: completion)
        } catch {
            print("Error exporting tokens: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // MARK: - Import Tokens
    
    public static func importTokens(completion: @escaping (Bool) -> Void) {
        importTokensIOS(completion: completion)
    }
    
    // MARK: - Export Tokens
    private static func exportTokens(from fileURL: URL, completion: @escaping (Bool) -> Void) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            completion(false)
            return
        }
        
        let documentPicker = UIDocumentPickerViewController(forExporting: [fileURL])
        
        // Use a delegate to handle completion
        let delegate = DocumentPickerDelegate()
        delegate.completionHandler = { _ in
            // Since export doesn't return the URL, we'll assume success if the delegate is called
            completion(true)
        }
        documentPicker.delegate = delegate
        
        // Keep a reference to the delegate
        objc_setAssociatedObject(documentPicker, &AssociatedObjectHandle, delegate, .OBJC_ASSOCIATION_RETAIN)
        
        rootVC.present(documentPicker, animated: true)
    }
    
    private static func importTokensIOS(completion: @escaping (Bool) -> Void) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            completion(false)
            return
        }
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        
        let delegate = DocumentPickerDelegate()
        delegate.completionHandler = { url in
            guard let url = url else {
                print("No file selected.")
                completion(false)
                return
            }
            
            processImportedFile(at: url, completion: completion)
        }
        documentPicker.delegate = delegate
        
        // Keep a reference to the delegate
        objc_setAssociatedObject(documentPicker, &AssociatedObjectHandle, delegate, .OBJC_ASSOCIATION_RETAIN)
        
        rootVC.present(documentPicker, animated: true)
    }
    
    // Document picker delegate for iOS
    private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
        var completionHandler: ((URL?) -> Void)?
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completionHandler?(urls.first)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completionHandler?(nil)
        }
    }
    
    // MARK: - Shared Implementation
    
    private static func processImportedFile(at url: URL, completion: @escaping (Bool) -> Void) {
        // Start security-scoped access
        guard url.startAccessingSecurityScopedResource() else {
            print("Could not access security scoped resource.")
            completion(false)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let jsonData = try Data(contentsOf: url)
            print("Read \(jsonData.count) bytes from file")
            
            // Try to decode as an array of custom ImportToken struct first
            let decoder = JSONDecoder()
            
            // Define a lightweight import model that matches the expected JSON format
            struct ImportToken: Decodable {
                let id: UUID
                let name: String
                let apiToken: String
                let isConnected: Bool
                let isActivated: Bool?
                let workspaceID: String?
                let workspaceName: String?
            }
            
            let importedTokens = try decoder.decode([ImportToken].self, from: jsonData)
            print("Decoded \(importedTokens.count) tokens")
            
            var savedCount = 0
            for importToken in importedTokens {
                print("Importing token named: \(importToken.name)")
                
                // Save using TokenDataController directly with more detailed approach
                if let savedToken = TokenDataController.shared.saveToken(
                    name: importToken.name,
                    apiToken: importToken.apiToken
                ) {
                    // Also update additional properties
                    TokenDataController.shared.updateToken(
                        id: savedToken.id!,
                        isConnected: importToken.isConnected,
                        isActivated: importToken.isActivated ?? false,
                        workspaceID: importToken.workspaceID,
                        workspaceName: importToken.workspaceName
                    )
                    savedCount += 1
                }
            }
            
            print("Successfully saved \(savedCount) of \(importedTokens.count) tokens")
            
            // Force UI update on main thread
            DispatchQueue.main.async {
                TokenService.shared.loadTokens()
                TokenService.shared.objectWillChange.send()
            }
            
            completion(true)
        } catch let error {
            print("Error importing tokens: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("Decoding error details: \(decodingError)")
            }
            completion(false)
        }
    }
}

// Required to maintain a reference to delegates in iOS
private var AssociatedObjectHandle: UInt8 = 0
