pub mod block;
pub mod consensus;
pub mod storage;
pub mod crypto;
pub mod network;

// Re-export key types for FFI
pub use block::Block;
pub use consensus::ProofOfAuthority;
pub use storage::BlockchainStorage;