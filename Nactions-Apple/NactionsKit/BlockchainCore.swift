// NactionsKit/BlockchainCore.swift
import Foundation

/// Swift wrapper for the Rust blockchain core
public class BlockchainCore {
    /// Singleton instance
    public static let shared = BlockchainCore()
    
    /// Whether the blockchain is initialized
    private var isInitialized = false
    
    /// Private initializer for singleton
    private init() {}
    
    /// Initialize the blockchain storage
    /// - Parameter directory: The directory to store blockchain data
    /// - Returns: Whether initialization was successful
    public func initialize(directory: URL) -> Bool {
        guard !isInitialized else { return true }
        
        let path = directory.path
        let result = path.withCString { pathPtr in
            NBC_initBlockchain(pathPtr)
        }
        
        isInitialized = result
        return result
    }
    
    /// Store encrypted data in the blockchain
    /// - Parameters:
    ///   - key: The key to store the data under
    ///   - data: The encrypted data to store
    ///   - type: The transaction type
    /// - Returns: Whether storage was successful
    public func storeData(key: String, data: Data, type: TransactionType) -> Bool {
        guard isInitialized else { return false }
        
        return key.withCString { keyPtr in
            data.withUnsafeBytes { dataPtr in
                NBC_storeData(keyPtr, dataPtr.baseAddress, data.count, type.rawValue)
            }
        }
    }
    
    /// Retrieve data from the blockchain
    /// - Parameters:
    ///   - key: The key to retrieve
    ///   - type: The transaction type
    /// - Returns: The retrieved data, if found
    public func retrieveData(key: String, type: TransactionType) -> Data? {
        guard isInitialized else { return nil }
        
        var dataPtr: UnsafeMutableRawPointer?
        var dataLength: Int = 0
        
        let success = key.withCString { keyPtr in
            NBC_retrieveData(keyPtr, type.rawValue, &dataPtr, &dataLength)
        }
        
        guard success, let ptr = dataPtr, dataLength > 0 else {
            return nil
        }
        
        // Copy the data
        let data = Data(bytes: ptr, count: dataLength)
        
        // Free the memory allocated by Rust
        NBC_freeMemory(dataPtr)
        
        return data
    }
    
    /// Shutdown the blockchain
    public func shutdown() {
        guard isInitialized else { return }
        
        NBC_shutdownBlockchain()
        isInitialized = false
    }
    
    deinit {
        shutdown()
    }
}

/// Transaction types
public enum TransactionType: UInt32 {
    case storeToken = 0
    case updateToken = 1
    case deleteToken = 2
    case storeCache = 3
    case updateCache = 4
    case deleteCache = 5
}
