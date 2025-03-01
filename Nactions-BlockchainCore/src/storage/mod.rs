use crate::block::{Block, Transaction, TransactionType};
use anyhow::{Result, anyhow};
use std::path::Path;
use leveldb::database::Database;
use leveldb::options::{Options, ReadOptions, WriteOptions};
use leveldb::kv::KV;
use bincode;

/// Storage interface for the blockchain
pub struct BlockchainStorage {
    /// LevelDB database for blocks
    blocks_db: Database<Vec<u8>>,
    /// LevelDB database for transactions
    transactions_db: Database<Vec<u8>>,
    /// Current head block hash
    head_hash: Option<Vec<u8>>,
}

impl BlockchainStorage {
    /// Create a new blockchain storage at the given path
    pub fn new<P: AsRef<Path>>(path: P) -> Result<Self> {
        let path = path.as_ref();
        
        // Create directory if it doesn't exist
        std::fs::create_dir_all(path)?;
        
        // Open or create blocks database
        let blocks_path = path.join("blocks");
        let mut options = Options::new();
        options.create_if_missing = true;
        let blocks_db = Database::open(&blocks_path, options.clone())?;
        
        // Open or create transactions database
        let tx_path = path.join("transactions");
        let transactions_db = Database::open(&tx_path, options)?;
        
        // Get head hash
        let mut read_opts = ReadOptions::new();
        let head_hash = blocks_db.get(read_opts, b"HEAD".to_vec())
            .map_err(|e| anyhow!("Failed to read HEAD: {}", e))?;
        
        Ok(BlockchainStorage {
            blocks_db,
            transactions_db,
            head_hash,
        })
    }
    
    /// Add a transaction to the blockchain
    pub fn add_transaction(&self, transaction: Transaction) -> Result<()> {
        // In a real implementation, this would:
        // 1. Validate the transaction
        // 2. Add it to a pending transaction pool
        // 3. Eventually include it in a block
        // 4. Commit the block to the chain
        
        // For simplicity, we'll just store the transaction directly
        let key = format!("tx:{}:{}", transaction.data.key, chrono::Utc::now().timestamp_millis());
        let data = bincode::serialize(&transaction)?;
        
        let write_opts = WriteOptions::new();
        self.transactions_db.put(write_opts, key.as_bytes().to_vec(), data)
            .map_err(|e| anyhow!("Failed to store transaction: {}", e))?;
        
        Ok(())
    }
    
    /// Get the latest transaction for a key and type
    pub fn get_latest_for_key(&self, key: &str, tx_type: &TransactionType) -> Result<Option<Transaction>> {
        // This is a simplified implementation
        // In reality, you'd query the state database or scan blocks
        
        // Prefix for this key
        let prefix = format!("tx:{}", key);
        
        let mut read_opts = ReadOptions::new();
        // Start iterating from the prefix
        read_opts.set_iterate_upper_bound(format!("tx:{}:", key).as_bytes().to_vec());
        
        let mut iter = self.transactions_db.iter(read_opts);
        iter.seek(&prefix.as_bytes().to_vec());
        
        let mut latest: Option<Transaction> = None;
        let mut latest_time = 0i64;
        
        while let Some((_, value)) = iter.next() {
            if let Ok(tx) = bincode::deserialize::<Transaction>(&value) {
                // Check if this is the type we're looking for
                if &tx.transaction_type == tx_type {
                    let time = tx.timestamp.timestamp_millis();
                    if time > latest_time {
                        latest_time = time;
                        latest = Some(tx);
                    }
                }
            }
        }
        
        Ok(latest)
    }
}