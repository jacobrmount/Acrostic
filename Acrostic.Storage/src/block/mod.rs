use crate::crypto::Hash;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Block {
    /// Block header containing metadata
    pub header: BlockHeader,
    /// Transactions contained in this block
    pub transactions: Vec<Transaction>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BlockHeader {
    /// Version of the block format
    pub version: u16,
    /// Hash of the previous block
    pub previous_hash: Hash,
    /// Merkle root of transactions
    pub merkle_root: Hash,
    /// Timestamp when the block was created
    pub timestamp: DateTime<Utc>,
    /// Block height in the chain
    pub height: u64,
    /// Validator signature
    pub validator_signature: Option<Vec<u8>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transaction {
    /// Transaction type
    pub transaction_type: TransactionType,
    /// Transaction data (can be different formats based on type)
    pub data: TransactionData,
    /// Transaction timestamp
    pub timestamp: DateTime<Utc>,
    /// Signature of the transaction creator
    pub signature: Vec<u8>,
    /// Public key of the transaction creator
    pub public_key: Vec<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TransactionType {
    /// Store a Notion token (encrypted)
    StoreToken,
    /// Update a Notion token
    UpdateToken,
    /// Delete a Notion token
    DeleteToken,
    /// Store cached Notion data
    StoreCache,
    /// Update cached Notion data
    UpdateCache,
    /// Delete cached Notion data
    DeleteCache,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionData {
    /// Key for the data (might be a user ID, token ID, etc.)
    pub key: String,
    /// Encrypted value
    pub value: Vec<u8>,
    /// Additional metadata
    pub metadata: HashMap<String, String>,
}

impl Block {
    /// Create a new block
    pub fn new(
        previous_hash: Hash,
        height: u64,
        transactions: Vec<Transaction>,
    ) -> Self {
        let timestamp = Utc::now();
        let merkle_root = Self::compute_merkle_root(&transactions);
        
        Block {
            header: BlockHeader {
                version: 1,
                previous_hash,
                merkle_root,
                timestamp,
                height,
                validator_signature: None,
            },
            transactions,
        }
    }
    
    /// Compute merkle root from transactions
    fn compute_merkle_root(transactions: &[Transaction]) -> Hash {
        // Simplified implementation - in production, use a proper Merkle tree
        let serialized = bincode::serialize(transactions).unwrap_or_default();
        blake3::hash(&serialized).into()
    }
}