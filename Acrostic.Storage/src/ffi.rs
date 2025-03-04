//! FFI interface for Swift

use libc::{c_char, c_void, size_t};
use std::ffi::{CStr, CString};
use std::slice;
use crate::block::{Block, Transaction, TransactionType, TransactionData};
use crate::storage::BlockchainStorage;
use std::collections::HashMap;
use std::sync::Arc;
use std::sync::Mutex;

// Global storage instance for C API
lazy_static::lazy_static! {
    static ref BLOCKCHAIN: Arc<Mutex<Option<BlockchainStorage>>> = Arc::new(Mutex::new(None));
}

/// Initialize the blockchain
#[no_mangle]
pub extern "C" fn NBC_initBlockchain(path: *const c_char) -> bool {
    let c_str = unsafe {
        if path.is_null() {
            return false;
        }
        CStr::from_ptr(path)
    };
    
    let path_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return false,
    };
    
    match BlockchainStorage::new(path_str) {
        Ok(storage) => {
            let mut blockchain = BLOCKCHAIN.lock().unwrap();
            *blockchain = Some(storage);
            true
        }
        Err(_) => false,
    }
}

/// Store data in the blockchain
#[no_mangle]
pub extern "C" fn NBC_storeData(
    key: *const c_char,
    data: *const c_void,
    data_len: size_t,
    transaction_type: u32,
) -> bool {
    // Check parameters
    if key.is_null() || data.is_null() || data_len == 0 {
        return false;
    }
    
    // Convert key to Rust string
    let key_cstr = unsafe { CStr::from_ptr(key) };
    let key_str = match key_cstr.to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return false,
    };
    
    // Convert data to Rust bytes
    let data_slice = unsafe {
        slice::from_raw_parts(data as *const u8, data_len)
    };
    
    // Determine transaction type
    let tx_type = match transaction_type {
        0 => TransactionType::StoreToken,
        1 => TransactionType::UpdateToken,
        2 => TransactionType::DeleteToken,
        3 => TransactionType::StoreCache,
        4 => TransactionType::UpdateCache,
        5 => TransactionType::DeleteCache,
        _ => return false,
    };
    
    // Create transaction
    let tx_data = TransactionData {
        key: key_str,
        value: data_slice.to_vec(),
        metadata: HashMap::new(),
    };
    
    let transaction = Transaction {
        transaction_type: tx_type,
        data: tx_data,
        timestamp: chrono::Utc::now(),
        signature: vec![],  // In real implementation, sign with user's key
        public_key: vec![],  // In real implementation, use user's public key
    };
    
    // Add to blockchain
    let blockchain = BLOCKCHAIN.lock().unwrap();
    if let Some(storage) = &*blockchain {
        match storage.add_transaction(transaction) {
            Ok(_) => true,
            Err(_) => false,
        }
    } else {
        false
    }
}

/// Retrieve data from the blockchain
#[no_mangle]
pub extern "C" fn NBC_retrieveData(
    key: *const c_char,
    transaction_type: u32,
    out_data: *mut *mut c_void,
    out_len: *mut size_t,
) -> bool {
    // Check parameters
    if key.is_null() || out_data.is_null() || out_len.is_null() {
        return false;
    }
    
    // Convert key to Rust string
    let key_cstr = unsafe { CStr::from_ptr(key) };
    let key_str = match key_cstr.to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return false,
    };
    
    // Determine transaction type
    let tx_type = match transaction_type {
        0 => TransactionType::StoreToken,
        1 => TransactionType::UpdateToken,
        2 => TransactionType::DeleteToken,
        3 => TransactionType::StoreCache,
        4 => TransactionType::UpdateCache,
        5 => TransactionType::DeleteCache,
        _ => return false,
    };
    
    // Get from blockchain
    let blockchain = BLOCKCHAIN.lock().unwrap();
    if let Some(storage) = &*blockchain {
        match storage.get_latest_for_key(&key_str, &tx_type) {
            Ok(Some(tx)) => {
                // Allocate memory for the result
                let data = tx.data.value;
                let data_len = data.len();
                
                let buffer = unsafe { libc::malloc(data_len) as *mut c_void };
                if buffer.is_null() {
                    return false;
                }
                
                // Copy data to output buffer
                unsafe {
                    std::ptr::copy_nonoverlapping(
                        data.as_ptr() as *const c_void,
                        buffer,
                        data_len
                    );
                    *out_data = buffer;
                    *out_len = data_len;
                }
                
                true
            },
            _ => false,
        }
    } else {
        false
    }
}

/// Free memory allocated by the FFI layer
#[no_mangle]
pub extern "C" fn NBC_freeMemory(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe {
            libc::free(ptr);
        }
    }
}

/// Shutdown the blockchain
#[no_mangle]
pub extern "C" fn NBC_shutdownBlockchain() -> bool {
    let mut blockchain = BLOCKCHAIN.lock().unwrap();
    *blockchain = None;
    true
}