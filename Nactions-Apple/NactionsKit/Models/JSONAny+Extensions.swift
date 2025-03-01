// NactionsKit/Models/JSONAny+Extensions.swift
import Foundation

extension JSONAny {
    // Get a safe dictionary from the JSONAny value
    public func getValueDictionary() -> [String: Any]? {
        // First check if the value is already a dictionary
        if let dict = value as? [String: Any] {
            return dict
        }
        
        // Try to handle wrapped dictionaries
        if let wrappedDict = value as? [String: JSONAny] {
            return wrappedDict.mapValues { $0.value }
        }
        
        // Debug information - print what type we're actually seeing
        print("⚠️ JSONAny value is not a dictionary. Type: \(type(of: value))")
        if let array = value as? [Any] {
            print("📊 Value is an array with \(array.count) elements")
            if let first = array.first {
                print("🔍 First element type: \(type(of: first))")
            }
        }
        
        return nil
    }
    
    // Get a safe array from the JSONAny value
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
    
    // Helper to safely extract a double value
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
    
    // Get a string value safely
    public func getStringValue(fromKey key: String) -> String? {
        guard let dict = getValueDictionary() else { return nil }
        
        return dict[key] as? String
    }
    
    // Debug function to print the structure of a JSONAny value
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
}
