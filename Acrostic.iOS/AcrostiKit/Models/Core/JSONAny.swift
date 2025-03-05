// AcrostiKit/Models/Core/JSONAny.swift
import Foundation

public class JSONAny: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    /// Safely extracts a string from the JSON value
    public func getString() -> String? {
        if let string = value as? String {
            return string
        }
        return nil
    }
    
    /// Safely extracts a boolean from the JSON value
    public func getBoolean() -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        // Handle number-encoded booleans
        if let number = value as? NSNumber {
            return number.boolValue
        }
        // Handle string-encoded booleans
        if let string = value as? String {
            switch string.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }
    
    /// Safely extracts a number from the JSON value
    public func getNumber() -> NSNumber? {
        if let number = value as? NSNumber {
            return number
        }
        // Handle string-encoded numbers
        if let string = value as? String,
           let double = Double(string) {
            return NSNumber(value: double)
        }
        return nil
    }
    
    /// Safely extracts a date from an ISO 8601 string
    public func getDate() -> Date? {
        if let string = getString() {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) {
                return date
            }
            
            // Try without fractional seconds if that failed
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: string)
        }
        return nil
    }
    
    /// Extracts a typed array of values
    public func getTypedArray<T>(_ transform: (Any) -> T?) -> [T]? {
        guard let array = getArray() else { return nil }
        
        let transformed = array.compactMap(transform)
        return transformed.isEmpty ? nil : transformed
    }
    
    /// Gets a nested property with type-safe conversion
    public func getNestedValue<T>(_ keyPath: [String], transform: (Any) -> T?) -> T? {
        guard !keyPath.isEmpty else { return nil }
        
        var current: Any? = value
        
        // Navigate through the key path
        for key in keyPath {
            guard let dict = current as? [String: Any],
                  let nestedValue = dict[key] else {
                return nil
            }
            current = nestedValue
        }
        
        if let result = current.flatMap(transform) {
            return result
        }
        
        return nil
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([JSONAny].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: JSONAny].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode JSONAny")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self.value {
        case is NSNull:
            try container.encodeNil()
        case let value as Bool:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        case let value as String:
            try container.encode(value)
        case let value as [Any]:
            try container.encode(value.map { JSONAny($0) })
        case let value as [String: Any]:
            try container.encode(value.mapValues { JSONAny($0) })
        default:
            throw EncodingError.invalidValue(self.value, EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Unable to encode JSONAny"
            ))
        }
    }
    
    // MARK: - Value Extraction Methods
    
    public func getValueDictionary() -> [String: Any]? {
        // First check if the value is already a dictionary
        if let dict = value as? [String: Any] {
            return dict
        }
        
        // Try to handle wrapped dictionaries
        if let wrappedDict = value as? [String: JSONAny] {
            return wrappedDict.mapValues { $0.value }
        }
        
        // Log if not a dictionary
        if let array = value as? [Any] {
            print("📊 Value is an array with \(array.count) elements")
            if let first = array.first {
                print("🔍 First element type: \(type(of: first))")
            }
        } else {
            print("⚠️ JSONAny value is not a dictionary. Type: \(type(of: value))")
        }
        
        return nil
    }
    
    public func getArray() -> [Any]? {
        // Try direct cast
        if let array = value as? [Any] {
            return array
        }
        
        // Try to handle wrapped arrays
        if let wrappedArray = value as? [JSONAny] {
            return wrappedArray.map { $0.value }
        }
        
        return nil
    }
    
    public func getNumberValue(fromKey key: String) -> Double? {
        guard let dict = getValueDictionary(),
              let value = dict[key] else {
            return nil
        }
        
        // Handle different number formats
        if let number = value as? Double {
            return number
        } else if let number = value as? Int {
            return Double(number)
        } else if let number = value as? String, let parsed = Double(number) {
            return parsed
        }
        
        return nil
    }
    
    public func getStringValue(fromKey key: String) -> String? {
        guard let dict = getValueDictionary() else { return nil }
        
        return dict[key] as? String
    }
    
    public func getBoolValue(fromKey key: String) -> Bool? {
        guard let dict = getValueDictionary(),
              let value = dict[key] else {
            return nil
        }
        
        return value as? Bool
    }
    
    public func getDateValue(fromKey key: String) -> Date? {
        guard let dict = getValueDictionary(),
              let dateString = dict[key] as? String else {
            return nil
        }
        
        // Try ISO8601 format
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return formatter.date(from: dateString)
    }
    
    public func getDictionaryValue(fromKey key: String) -> [String: Any]? {
        guard let dict = getValueDictionary(),
              let value = dict[key] else {
            return nil
        }
        
        if let nestedDict = value as? [String: Any] {
            return nestedDict
        } else if let jsonAny = value as? JSONAny {
            return jsonAny.getValueDictionary()
        }
        
        return nil
    }
    
    public func getArrayValue(fromKey key: String) -> [Any]? {
        guard let dict = getValueDictionary(),
              let value = dict[key] else {
            return nil
        }
        
        if let array = value as? [Any] {
            return array
        } else if let jsonAny = value as? JSONAny {
            return jsonAny.getArray()
        }
        
        return nil
    }
    
    // MARK: - Debug Utilities
    
    public func debugPrintStructure(label: String = "JSONAny", level: Int = 0) {
        let indent = String(repeating: "  ", count: level)
        let type = Swift.type(of: value)
        
        print("\(indent)🔍 \(label) (Type: \(type))")
        
        switch value {
        case let dict as [String: Any]:
            print("\(indent)📚 Dictionary with \(dict.count) keys:")
            for (key, value) in dict {
                if let nestedValue = value as? [String: Any] {
                    print("\(indent)  🔑 \(key): nested dictionary with \(nestedValue.count) keys")
                } else if let array = value as? [Any] {
                    print("\(indent)  🔑 \(key): array with \(array.count) elements")
                } else {
                    print("\(indent)  🔑 \(key): \(value) (Type: \(Swift.type(of: value)))")
                }
            }
            
        case let array as [Any]:
            print("\(indent)📊 Array with \(array.count) elements")
            if array.count > 0 {
                print("\(indent)  First element: \(array[0]) (Type: \(Swift.type(of: array[0])))")
            }
            
        default:
            print("\(indent)📄 Value: \(value)")
        }
    }
    
    public var dictionary: [String: Any]? {
        return value as? [String: Any]
    }
}

// MARK: - Notion-specific Extensions

extension JSONAny {
    
    /// Creates a notion rich text object
    public static func richText(content: String) -> [String: Any] {
        return [
            "rich_text": [
                [
                    "type": "text",
                    "text": [
                        "content": content
                    ]
                ]
            ]
        ]
    }
    
    /// Creates a notion title object
    public static func title(content: String) -> [String: Any] {
        return [
            "title": [
                [
                    "type": "text",
                    "text": [
                        "content": content
                    ]
                ]
            ]
        ]
    }
    
    /// Creates a notion checkbox property
    public static func checkbox(checked: Bool) -> [String: Any] {
        return [
            "checkbox": checked
        ]
    }
    
    /// Creates a notion date property
    public static func date(start: Date, end: Date? = nil) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var dateObj: [String: Any] = [
            "start": formatter.string(from: start)
        ]
        
        if let end = end {
            dateObj["end"] = formatter.string(from: end)
        }
        
        return [
            "date": dateObj
        ]
    }
    
    /// Creates a notion select property
    public static func select(name: String) -> [String: Any] {
        return [
            "select": [
                "name": name
            ]
        ]
    }
    
    /// Creates a notion multi-select property
    public static func multiSelect(names: [String]) -> [String: Any] {
        let options = names.map { ["name": $0] }
        return [
            "multi_select": options
        ]
    }
    
    /// Creates a notion number property
    public static func number(value: Double) -> [String: Any] {
        return [
            "number": value
        ]
    }
    
    /// Creates a notion url property
    public static func url(value: String) -> [String: Any] {
        return [
            "url": value
        ]
    }
    
    /// Creates a notion email property
    public static func email(value: String) -> [String: Any] {
        return [
            "email": value
        ]
    }
    
    /// Creates a notion phone number property
    public static func phoneNumber(value: String) -> [String: Any] {
        return [
            "phone_number": value
        ]
    }
    
    /// Creates a notion relation property
    public static func relation(pageIDs: [String]) -> [String: Any] {
        let relations = pageIDs.map { ["id": $0] }
        return [
            "relation": relations
        ]
    }
    
    /// Creates a block of the specified type
    public static func block(type: String, content: [String: Any]) -> [String: Any] {
        return [
            "object": "block",
            "type": type,
            type: content
        ]
    }
    
    /// Creates a paragraph block
    public static func paragraphBlock(text: String) -> [String: Any] {
        return block(type: "paragraph", content: [
            "rich_text": [
                [
                    "type": "text",
                    "text": [
                        "content": text
                    ]
                ]
            ]
        ])
    }
    
    /// Creates a heading block (level 1-3)
    public static func headingBlock(text: String, level: Int) -> [String: Any] {
        guard (1...3).contains(level) else {
            fatalError("Heading level must be between 1 and 3")
        }
        
        let type = "heading_\(level)"
        return block(type: type, content: [
            "rich_text": [
                [
                    "type": "text",
                    "text": [
                        "content": text
                    ]
                ]
            ]
        ])
    }
    
    /// Creates a to-do block
    public static func todoBlock(text: String, checked: Bool = false) -> [String: Any] {
        return block(type: "to_do", content: [
            "rich_text": [
                [
                    "type": "text",
                    "text": [
                        "content": text
                    ]
                ]
            ],
            "checked": checked
        ])
    }
    
    /// Creates a bulleted list item block
    public static func bulletedListItemBlock(text: String) -> [String: Any] {
        return block(type: "bulleted_list_item", content: [
            "rich_text": [
                [
                    "type": "text",
                    "text": [
                        "content": text
                    ]
                ]
            ]
        ])
    }
    
    /// Creates a numbered list item block
    public static func numberedListItemBlock(text: String) -> [String: Any] {
        return block(type: "numbered_list_item", content: [
            "rich_text": [
                [
                    "type": "text",
                    "text": [
                        "content": text
                    ]
                ]
            ]
        ])
    }
    
    /// Creates a code block
    public static func codeBlock(code: String, language: String) -> [String: Any] {
        return block(type: "code", content: [
            "rich_text": [
                [
                    "type": "text",
                    "text": [
                        "content": code
                    ]
                ]
            ],
            "language": language
        ])
    }
    
    /// Creates a divider block
    public static func dividerBlock() -> [String: Any] {
        return block(type: "divider", content: [:])
    }
    
    /// Helper for extracting a property from a Notion page or database response
    public func findProperty(named propertyName: String) -> JSONAny? {
        guard let properties = getValueDictionary()?["properties"] as? [String: Any] else {
            return nil
        }
        
        // Try exact match first
        if let property = properties[propertyName] {
            return JSONAny(property)
        }
        
        // Try case-insensitive match
        for (key, value) in properties {
            if key.lowercased() == propertyName.lowercased() {
                return JSONAny(value)
            }
        }
        
        // Try contains match
        for (key, value) in properties {
            if key.lowercased().contains(propertyName.lowercased()) {
                return JSONAny(value)
            }
        }
        
        return nil
    }
    
    /// Helper for extracting title from a Notion page
    public func extractPageTitle() -> String {
        // Look for a property called "title" or containing "name"
        if let titleProperty = findProperty(named: "title") {
            if let titleArray = titleProperty.getArrayValue(fromKey: "title") {
                return extractTextFromRichTextArray(titleArray)
            }
        }
        
        if let nameProperty = findProperty(named: "name") {
            if let nameArray = nameProperty.getArrayValue(fromKey: "title") {
                return extractTextFromRichTextArray(nameArray)
            }
        }
        
        return "Untitled"
    }
    
    /// Helper for extracting text from a rich text array
    private func extractTextFromRichTextArray(_ array: [Any]) -> String {
        return array.compactMap { item -> String? in
            guard let itemDict = item as? [String: Any],
                  let text = itemDict["plain_text"] as? String else {
                return nil
            }
            return text
        }.joined()
    }
}
