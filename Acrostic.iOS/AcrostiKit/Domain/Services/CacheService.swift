// AcrostiKit/Domain/Services/CacheService.swift
import Foundation

public enum CacheType {
    case token
    case database
    case task
    case widget
    
    var key: String {
        switch self {
        case .token: return "acrostic_tokens_cache"
        case .database: return "acrostic_database_metadata_cache"
        case .task: return "acrostic_tasks_cache"
        case .widget: return "acrostic_widget_data_cache"
        }
    }
}

public class CacheService {
    public static let shared = CacheService()
    
    private let userDefaults: UserDefaults?
    
    private init() {
        userDefaults = AppGroupConfig.sharedUserDefaults
    }
    
    // Generic cache storage method
    public func store<T: Encodable>(_ object: T, type: CacheType, identifier: String? = nil) {
        guard let userDefaults = userDefaults else { return }
        
        let key = identifier != nil ? "\(type.key)_\(identifier!)" : type.key
        
        let cacheData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "data": object
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: cacheData)
            userDefaults.set(data, forKey: key)
            userDefaults.synchronize()
        } catch {
            print("Error storing cache: \(error)")
        }
    }
    
    // Generic cache retrieval method
    public func retrieve<T: Decodable>(type: CacheType, identifier: String? = nil, maxAge: TimeInterval = 86400) -> T? {
        guard let userDefaults = userDefaults else { return nil }
        
        let key = identifier != nil ? "\(type.key)_\(identifier!)" : type.key
        
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            let cacheContainer = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let timestamp = cacheContainer?["timestamp"] as? TimeInterval,
                  let cachedData = cacheContainer?["data"] as? T else {
                return nil
            }
            
            // Check cache age
            let cacheAge = Date().timeIntervalSince1970 - timestamp
            if cacheAge > maxAge {
                return nil
            }
            
            return cachedData
        } catch {
            print("Error retrieving cache: \(error)")
            return nil
        }
    }
    
    // Cleanup method to remove expired caches
    public func cleanupExpiredCaches(olderThan maxAge: TimeInterval = 604800) {
        guard let userDefaults = userDefaults else { return }
        
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let cacheKeys = allKeys.filter { $0.starts(with: "acrostic_") }
        let now = Date().timeIntervalSince1970
        
        for key in cacheKeys {
            if let data = userDefaults.data(forKey: key),
               let cacheContainer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let timestamp = cacheContainer["timestamp"] as? TimeInterval,
               now - timestamp > maxAge {
                
                userDefaults.removeObject(forKey: key)
            }
        }
        
        userDefaults.synchronize()
    }
}
