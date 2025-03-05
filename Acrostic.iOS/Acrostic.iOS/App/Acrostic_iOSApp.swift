// Acrostic.iOS/App/Acrostic_iOSApp.swift
import SwiftUI
import AcrostiKit
import CoreData

@main
struct AcrosticApp: App {
    // Initialize Core Data stack
    let coreDataStack = CoreDataStack.shared
    
    init() {
        print("⚡ Acrostic app initializing...")
        
        // Register default settings
        registerDefaults()
        
        // Set up Core Data transformers
        setupValueTransformers()
        
        // Diagnostic logging
        AppGroupConfig.logAppGroupDiagnostics()
        
        // Configure app for widget sharing
        AppGroupConfig.configureAppForWidgetSharing()
        
        // Register for background refresh
        setupBackgroundTasks()
        
        // Initialize Core Data stack and verify model
        let coreDataStack = CoreDataStack.shared
        coreDataStack.verifyModelAccess()
        
        // Execute Core Data migration on a background Task
        Task {
            do {
                let migration = CoreDataMigration(coreDataStack: coreDataStack)
                try await migration.migrateIfNeeded()
                print("✅ Core Data migration completed successfully or not needed")
                
                // Fix database entities after migration
                DatabaseFixer.shared.fixDatabaseEntities()
                CoreDataStack.shared.debugDatabaseEntities()
            } catch {
                print("❌ Migration failed: \(error)")
                // Continue app initialization even with Core Data errors
            }
        }
        
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
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "storage_location_preference": "icloud"
        ])
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
        Task {
            print("🔄 App launch: Loading essential data")
            
            // Step 1: Load tokens (required for everything else)
            await TokenService.shared.refreshAllTokens()
            
            // Step 2: Only if tokens are activated, load file metadata (titles only)
            if !TokenService.shared.activatedTokens.isEmpty {
                await FileService.shared.loadFileMetadata()
            }
            
            // Step 3: Share minimal data with widgets
            await AppGroupConfig.refreshWidgetData()
        }
    }
    
    // DatabaseValdation
    func runDatabaseValidationOnStartup() {
        Task {
            // Fix any broken database entities
            DatabaseFixer.shared.fixDatabaseEntities()
        }
    }
    
    func performDatabaseHealthCheck() {
        Task {
            // First, run a diagnostic on existing databases
            CoreDataStack.shared.debugDatabaseEntities()
            
            // Attempt to fix any databases with nil IDs
            await fixDatabasesWithNilIDs()
        }
    }

    func fixDatabasesWithNilIDs() async {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.predicate = NSPredicate(format: "id == nil")
        
        do {
            let badDatabases = try context.fetch(request)
            if !badDatabases.isEmpty {
                print("🛠 Found \(badDatabases.count) databases with nil IDs to fix/remove")
                
                for database in badDatabases {
                    // Option 1: Try to fix if we can identify it
                    if let title = database.value(forKey: "title") as? String,
                       title == "Tasks",
                       let url = database.value(forKey: "url") as? String,
                       url == "https://www.notion.so/15bed8dc2e838174bb19d5423c4e2ddf" {
                        
                        print("🔧 Fixing known database: Tasks")
                        // Extract ID from the URL or use a fallback
                        let id = "15bed8dc2e838174bb19d5423c4e2ddf"
                        database.setValue(id, forKey: "id")
                    } else {
                        // Option 2: Remove if we can't identify it
                        print("🗑 Removing unidentifiable database with nil ID")
                        context.delete(database)
                    }
                }
                
                try context.save()
                print("✅ Fixed/removed databases with nil IDs")
            }
        } catch {
            print("❌ Error fixing databases with nil IDs: \(error)")
        }
    }
}
