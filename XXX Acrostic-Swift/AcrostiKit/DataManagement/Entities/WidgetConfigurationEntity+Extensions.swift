// NactionsKit/DataManagement/Entities/WidgetConfigurationEntity+Extensions.swift
import Foundation
import CoreData

public extension WidgetConfigurationEntity {
    /// Serializes a configuration dictionary to Data for storage
    func setConfiguration(_ config: [String: Any]) {
        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: config,
                format: .binary,
                options: 0
            )
            self.configData = data
        } catch {
            print("Error serializing widget configuration: \(error)")
        }
    }
    
    /// Deserializes stored Data to a configuration dictionary
    func getConfiguration() -> [String: Any]? {
        guard let data = self.configData else { return nil }
        
        do {
            let config = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]
            return config
        } catch {
            print("Error deserializing widget configuration: \(error)")
            return nil
        }
    }
    
    /// Creates a new WidgetConfiguration object
    static func create(name: String,
                     tokenID: UUID,
                     databaseID: String?,
                     widgetKind: String,
                     widgetFamily: String,
                     config: [String: Any],
                     in context: NSManagedObjectContext) -> WidgetConfigurationEntity {
        let widget = WidgetConfigurationEntity(context: context)
        widget.id = UUID()
        widget.name = name
        widget.tokenID = tokenID
        widget.databaseID = databaseID
        widget.widgetKind = widgetKind
        widget.widgetFamily = widgetFamily
        widget.lastUpdated = Date()
        widget.setConfiguration(config)
        return widget
    }
}
