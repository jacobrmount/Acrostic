// AcrostiKit/Models/NotionProperty.swift
import Foundation

// MARK: - Property Schema Types

/// Represents a database property schema
public struct NotionPropertySchema: Codable {
    public let id: String
    public let name: String
    public let type: String
    public let configuration: JSONAny?
    
    enum CodingKeys: String, CodingKey {
        case id, name, type
        // We'll handle the dynamic configuration based on type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        
        // Decode the appropriate configuration based on type
        let configContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        if let key = DynamicCodingKeys(stringValue: type) {
            configuration = try configContainer.decodeIfPresent(JSONAny.self, forKey: key)
        } else {
            configuration = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        
        // Encode the configuration under the appropriate key
        if let configuration = configuration {
            var configContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
            if let key = DynamicCodingKeys(stringValue: type) {
                try configContainer.encode(configuration, forKey: key)
            }
        }
    }
    
    // Helper struct for dynamic property types in JSON
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
}

// MARK: - Property Value Types

/// Represents a property value from a page
public struct NotionPropertyValue: Codable {
    public let id: String
    public let type: String
    public let value: JSONAny
    
    enum CodingKeys: String, CodingKey {
        case id, type
        // We'll handle the dynamic value based on type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle required fields
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        
        // Try to decode the appropriate value based on type
        let valueContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        if let key = DynamicCodingKeys(stringValue: type) {
            do {
                value = try valueContainer.decode(JSONAny.self, forKey: key)
            } catch {
                // If decoding fails, provide a default empty value
                print("Warning: Failed to decode value for property type \(type): \(error)")
                value = JSONAny([:])
            }
        } else {
            // Default empty value if type is unknown
            value = JSONAny([:])
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        
        // Encode the value under the appropriate key
        var valueContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
        if let key = DynamicCodingKeys(stringValue: type) {
            try valueContainer.encode(value, forKey: key)
        }
    }
    
    // Helper struct for dynamic property types in JSON
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
    
    // MARK: - Type-specific value accessors
    
    // Update the extractTitle method to be more robust

    public func extractTitle() -> [NotionRichText]? {
        guard type == "title" else { return nil }
        
        if let titleArray = value.getArrayValue(fromKey: "title") {
            // Parse the array of rich text objects
            return parseRichTextArray(titleArray)
        }
        
        return nil
    }

    // Add a helper method for parsing rich text arrays
    private func parseRichTextArray(_ array: [Any]) -> [NotionRichText]? {
        var richTexts: [NotionRichText] = []
        
        for item in array {
            if let itemDict = item as? [String: Any],
               let plainText = itemDict["plain_text"] as? String {
                
                let href = itemDict["href"] as? String
                let type = itemDict["type"] as? String ?? "text"
                
                // Parse annotations if present
                var annotations: NotionAnnotations? = nil
                if let annotationsDict = itemDict["annotations"] as? [String: Any] {
                    annotations = NotionAnnotations(
                        bold: annotationsDict["bold"] as? Bool ?? false,
                        italic: annotationsDict["italic"] as? Bool ?? false,
                        strikethrough: annotationsDict["strikethrough"] as? Bool ?? false,
                        underline: annotationsDict["underline"] as? Bool ?? false,
                        code: annotationsDict["code"] as? Bool ?? false,
                        color: annotationsDict["color"] as? String ?? "default"
                    )
                }
                
                // Create a NotionRichText from the dictionary
                let richText = NotionRichText(
                    plainText: plainText,
                    type: type,
                    href: href,
                    annotations: annotations
                )
                
                richTexts.append(richText)
            }
        }
        
        return richTexts.isEmpty ? nil : richTexts
    }
    
    /// Extracts rich text from appropriate property types
    public func extractRichText() -> [NotionRichText]? {
        guard ["title", "rich_text", "text"].contains(type) else { return nil }
        
        if let textArray = value.getArrayValue(fromKey: type) {
            // Parse the array of rich text objects
            var richTexts: [NotionRichText] = []
            
            for item in textArray {
                if let itemDict = item as? [String: Any],
                   let plainText = itemDict["plain_text"] as? String {
                    
                    let href = itemDict["href"] as? String
                    
                    // Create a basic NotionRichText from the dictionary
                    let richText = NotionRichText(
                        plainText: plainText,
                        type: itemDict["type"] as? String ?? "text",
                        href: href
                    )
                    
                    richTexts.append(richText)
                }
            }
            
            return richTexts
        }
        
        return nil
    }
    
    /// Extracts checkbox value
    public func extractCheckbox() -> Bool? {
        guard type == "checkbox" else { return nil }
        return value.getBoolValue(fromKey: type)
    }
    
    /// Extracts select value
    public func extractSelect() -> (id: String?, name: String?, color: String?)? {
        guard type == "select" else { return nil }
        
        if let selectDict = value.getDictionaryValue(fromKey: type) {
            return (
                id: selectDict["id"] as? String,
                name: selectDict["name"] as? String,
                color: selectDict["color"] as? String
            )
        }
        
        return nil
    }
    
    // extractDate method using new JSONAny helpers
    public func extractDate() -> Date? {
        guard type == "date" else { return nil }
        
        if let dateDict = value.getDictionaryValue(fromKey: "date") {
            if let startDateStr = dateDict["start"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter.date(from: startDateStr)
            }
        }
        
        // Try more direct approach using our new helper
        return value.getNestedValue(["date", "start"]) { any in
            if let dateStr = any as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter.date(from: dateStr)
            }
            return nil
        }
    }

    // Add method to extract file URL values
    public func extractFileURL() -> String? {
        guard type == "files" else { return nil }
        
        if let filesArray = value.getArrayValue(fromKey: "files"),
           !filesArray.isEmpty,
           let firstFile = filesArray.first as? [String: Any],
           let fileType = firstFile["type"] as? String {
            
            // Handle both internal and external files
            if fileType == "file", let fileData = firstFile["file"] as? [String: Any] {
                return fileData["url"] as? String
            } else if fileType == "external", let externalData = firstFile["external"] as? [String: Any] {
                return externalData["url"] as? String
            }
        }
        
        return nil
    }

    // Add method to extract people mentions
    public func extractPeople() -> [String]? {
        guard type == "people" else { return nil }
        
        if let peopleArray = value.getArrayValue(fromKey: "people") {
            return peopleArray.compactMap { person in
                if let personDict = person as? [String: Any],
                   let name = personDict["name"] as? String {
                    return name
                }
                return nil
            }
        }
        
        return nil
    }

    // Add method to extract multi-select values
    public func extractMultiSelect() -> [(id: String?, name: String?, color: String?)]? {
        guard type == "multi_select" else { return nil }
        
        if let multiSelectArray = value.getArrayValue(fromKey: "multi_select") {
            return multiSelectArray.compactMap { item in
                if let itemDict = item as? [String: Any] {
                    return (
                        id: itemDict["id"] as? String,
                        name: itemDict["name"] as? String,
                        color: itemDict["color"] as? String
                    )
                }
                return nil
            }
        }
        
        return nil
    }
    
    /// Extracts number value
    public func extractNumber() -> Double? {
        guard type == "number" else { return nil }
        return value.getNumberValue(fromKey: type)
    }
    
    /// Extracts URL value
    public func extractURL() -> String? {
        guard type == "url" else { return nil }
        return value.getStringValue(fromKey: type)
    }
    
    /// Extracts email value
    public func extractEmail() -> String? {
        guard type == "email" else { return nil }
        return value.getStringValue(fromKey: type)
    }
    
    /// Extracts phone number value
    public func extractPhoneNumber() -> String? {
        guard type == "phone_number" else { return nil }
        return value.getStringValue(fromKey: type)
    }
    
    /// Extracts formula result based on formula type
    public func extractFormula() -> Any? {
        guard type == "formula" else { return nil }
        
        if let formulaDict = value.getDictionaryValue(fromKey: type),
           let formulaType = formulaDict["type"] as? String {
            
            switch formulaType {
            case "string":
                return formulaDict["string"] as? String
            case "number":
                return formulaDict["number"] as? Double
            case "boolean":
                return formulaDict["boolean"] as? Bool
            case "date":
                if let dateDict = formulaDict["date"] as? [String: Any],
                   let startString = dateDict["start"] as? String {
                    
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter.date(from: startString)
                }
            default:
                return nil
            }
        }
        
        return nil
    }
}
