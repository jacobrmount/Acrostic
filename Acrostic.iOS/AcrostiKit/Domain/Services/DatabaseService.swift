// AcrostiKit/Domain/Services/DatabaseService.swift
import Foundation
import Combine
import CoreData

public class DatabaseService: ObservableObject {
    @Published public var databaseGroups: [DatabaseGroup] = []
    @Published public var errorMessage: String? = nil
    @Published public var isLoading: Bool = false
    
    private let controller = DatabaseController.shared
    
    public static let shared = DatabaseService()
    
    private init() {
        // Initialize with data from the controller
        self.databaseGroups = controller.databaseGroups
        self.errorMessage = controller.errorMessage
        self.isLoading = controller.isLoading
        
        // Set up observation of the controller's state
        updateFromController()
    }
    
    public func loadDatabaseMetadata() async {
        await controller.loadDatabaseMetadata()
        await MainActor.run {
            updateFromController()
        }
    }
    
    private func updateFromController() {
        self.databaseGroups = controller.databaseGroups
        self.errorMessage = controller.errorMessage
        self.isLoading = controller.isLoading
    }
    
    // Add other forwarding methods as needed
    public func toggleWidgetEnabled(databaseID: String, enabled: Bool) {
        controller.toggleWidgetEnabled(databaseID: databaseID, enabled: enabled)
        updateFromController()
    }
}
