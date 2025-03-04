// AcrostiKitTests/CoreDataTestHelper.swift
import XCTest
import CoreData
@testable import AcrostiKit

class CoreDataTestHelper: XCTestCase {
    
    var testContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Set up with your existing model
        testContainer = NSPersistentContainer(name: "AcrosticDataModel")
        
        // Configure for in-memory testing
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        testContainer.persistentStoreDescriptions = [description]
        
        testContainer.loadPersistentStores { (description, error) in
            if let error = error as NSError? {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        testContext = testContainer.viewContext
    }
    
    override func tearDownWithError() throws {
        // Reset store after each test
        let coordinator = testContainer.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
        
        testContainer = nil
        testContext = nil
        
        try super.tearDownWithError()
    }
    
    // Helper to create token
    func createTestToken(name: String = "Test Token") -> TokenEntity {
        let token = TokenEntity(context: testContext)
        token.id = UUID()
        token.name = name
        token.connectionStatus = false
        token.isActivated = false
        token.lastValidated = Date()
        token.workspaceID = "workspace_\(UUID().uuidString)"
        token.workspaceName = "Test Workspace"
        
        try? testContext.save()
        return token
    }
    
    // Helper to create database
    func createTestDatabase(title: String = "Test Database", token: TokenEntity? = nil) -> DatabaseEntity {
        let database = DatabaseEntity(context: testContext)
        database.id = UUID().uuidString
        database.title = title
        database.databaseDescription = "A test database description"
        database.createdTime = Date().addingTimeInterval(-86400)
        database.lastEditedTime = Date()
        database.lastSyncTiime = Date()
        database.url = "https://notion.so/\(UUID().uuidString)"
        database.widgetEnabled = false
        database.widgetType = "task_list"
        database.token = token
        
        try? testContext.save()
        return database
    }
    
    // Helper to create page
    func createTestPage(title: String = "Test Page", database: DatabaseEntity? = nil) -> PageEntity {
        let page = PageEntity(context: testContext)
        page.id = UUID().uuidString
        page.title = title
        page.createdTime = Date().addingTimeInterval(-3600)
        page.lastEditedTime = Date()
        page.lastSyncTime = Date()
        page.url = "https://notion.so/pages/\(UUID().uuidString)"
        page.archived = false
        
        if let database = database {
            page.parentDatabaseID = database.id
            page.database = database
        }
        
        try? testContext.save()
        return page
    }
    
    // Helper to create task
    func createTestTask(title: String = "Test Task", isCompleted: Bool = false, databaseID: String) -> TaskEntity {
        let task = TaskEntity(context: testContext)
        task.id = UUID().uuidString
        task.title = title
        task.isCompleted = isCompleted
        task.dueDate = Date().addingTimeInterval(86400)
        task.databaseID = databaseID
        task.pageID = UUID().uuidString
        task.lastSyncTime = Date()
        
        try? testContext.save()
        return task
    }
    
    // Helper to create widget configuration
    func createTestWidgetConfiguration(name: String = "Test Widget",
                                      token: TokenEntity,
                                      database: DatabaseEntity? = nil) -> WidgetConfigurationEntity {
        let widget = WidgetConfigurationEntity(context: testContext)
        widget.id = UUID()
        widget.name = name
        widget.tokenID = token.id
        widget.databaseID = database?.id
        widget.widgetKind = "task_list"
        widget.widgetFamily = "medium"
        widget.lastUpdated = Date()
        
        // Create demo configuration data
        let config: [String: Any] = [
            "showCompleted": false,
            "maxItems": 5,
            "sortOrder": "dueDate"
        ]
        
        let data = try! PropertyListSerialization.data(
            fromPropertyList: config,
            format: .binary,
            options: 0
        )
        widget.configData = data
        
        try? testContext.save()
        return widget
    }
}
