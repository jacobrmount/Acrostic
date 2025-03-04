// TokenEntityRelationshipTests.swift
import XCTest
@testable import AcrostiKit
import CoreData

class TokenEntityRelationshipTests: CoreDataTestHelper {
    
    func testTokenDatabaseRelationship() {
        // Create a test token
        let token = createTestToken(name: "Token With Databases")
        
        // Create databases linked to this token
        let database1 = createTestDatabase(title: "Database 1", token: token)
        let database2 = createTestDatabase(title: "Database 2", token: token)
        
        // Verify token-database relationship
        let fetchRequest: NSFetchRequest<DatabaseEntity> = DatabaseEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "token.id == %@", token.id! as CVarArg)
        
        do {
            let databases = try testContext.fetch(fetchRequest)
            XCTAssertEqual(databases.count, 2)
            
            let titles = databases.map { $0.title ?? <#default value#> }.sorted()
            XCTAssertEqual(titles, ["Database 1", "Database 2"])
        } catch {
            XCTFail("Failed to fetch databases: \(error)")
        }
    }
    
    func testDatabasePageRelationship() {
        // Create token and database
        let token = createTestToken()
        let database = createTestDatabase(token: token)
        
        // Create pages in the database
        let page1 = createTestPage(title: "Page 1", database: database)
        let page2 = createTestPage(title: "Page 2", database: database)
        
        // Verify the relationship
        let fetchRequest: NSFetchRequest<PageEntity> = PageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "database.id == %@", database.id!)
        
        do {
            let pages = try testContext.fetch(fetchRequest)
            XCTAssertEqual(pages.count, 2)
            
            let pageTitles = pages.map { $0.title ?? <#default value#> }.sorted()
            XCTAssertEqual(pageTitles, ["Page 1", "Page 2"])
        } catch {
            XCTFail("Failed to fetch pages: \(error)")
        }
    }
    
    func testWidgetConfiguration() {
        // Create token and database
        let token = createTestToken()
        let database = createTestDatabase(token: token)
        
        // Create widget configuration
        let widget = createTestWidgetConfiguration(name: "Tasks Widget", token: token, database: database)
        
        // Verify configuration data can be retrieved
        if let configData = widget.configData {
            do {
                let config = try PropertyListSerialization.propertyList(
                    from: configData,
                    options: [],
                    format: nil
                ) as? [String: Any]
                
                XCTAssertNotNil(config)
                XCTAssertEqual(config?["showCompleted"] as? Bool, false)
                XCTAssertEqual(config?["maxItems"] as? Int, 5)
            } catch {
                XCTFail("Failed to deserialize widget config: \(error)")
            }
        } else {
            XCTFail("Widget config data is nil")
        }
    }
    
    func testTasksForDatabase() {
        // Create token and database
        let token = createTestToken()
        let database = createTestDatabase(token: token)
        
        // Create tasks for this database
        createTestTask(title: "Task 1", isCompleted: false, databaseID: database.id!)
        createTestTask(title: "Task 2", isCompleted: true, databaseID: database.id!)
        
        // Verify tasks
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "databaseID == %@", database.id!)
        
        do {
            let tasks = try testContext.fetch(fetchRequest)
            XCTAssertEqual(tasks.count, 2)
            
            // Verify we have one completed task
            let completedTasks = tasks.filter { $0.isCompleted }
            XCTAssertEqual(completedTasks.count, 1)
        } catch {
            XCTFail("Failed to fetch tasks: \(error)")
        }
    }
}
