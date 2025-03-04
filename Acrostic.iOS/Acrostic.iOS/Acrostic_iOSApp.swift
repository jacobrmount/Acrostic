// Acrostic.iOS/Acrostic_iOSApp.swift
import SwiftUI
import AcrostiKit

@main
struct AcrosticApp: App {
    // Initialize Core Data stack
    let coreDataStack = CoreDataStack.shared
    
    init() {
        print("⚡ Acrostic app initializing...")
        
        // Set up Core Data transformers
        setupValueTransformers()
        
        // Configure app for widget sharing
        AppGroupConfig.configureAppForWidgetSharing()
        
        // Register for background refresh
        setupBackgroundTasks()
        
        // Initialize Core Data stack and verify model
        let coreDataStack = CoreDataStack.shared
        coreDataStack.verifyModelAccess()
        
        // Verify app group access
        let groupAccessSuccessful = AppGroupConfig.verifyAppGroupAccess()
        if !groupAccessSuccessful {
            print("⚠️ Failed to access app group - widgets may not work correctly")
        } else {
            print("✅ App group access configured successfully")
            
            // Perform an immediate data share to widgets on app launch
            Task {
                await AppGroupConfig.refreshWidgetData()
            }
        }
        
        print("✅ Acrostic app initialization complete")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.viewContext)
                .onAppear {
                    refreshDataOnLaunch()
                }
        }
    }
    
    private func setupBackgroundTasks() {
        TokenRefreshScheduler.shared.registerBackgroundTask()
        TokenRefreshScheduler.shared.scheduleTokenRefresh()
    }
    
    private func setupValueTransformers() {
        // Register needed CoreData transformers
        // This is normally a placeholder for any Core Data transformer registration
        // if using any custom transformers, they would be registered here
    }
    
    private func refreshDataOnLaunch() {
        // Refresh tokens when app launches
        Task {
            print("🔄 Refreshing data on app launch")
            await TokenService.shared.refreshAllTokens()
            
            // Share data with widgets
            await AppGroupConfig.refreshWidgetData()
            
            // Clean up old cache data
            AppGroupConfig.cleanupCacheData()
        }
    }
}
