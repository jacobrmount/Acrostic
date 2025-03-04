use serde::{Deserialize, Serialize};
use ed25519_dalek::{Keypair, PublicKey, SecretKey, Signature};
use rand::rngs::OsRng;

/// A 32-byte hash
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Hash([u8; 32]);

impl From<blake3::Hash> for Hash {
    fn from(hash: blake3::Hash) -> Self {
        let mut bytes = [0u8; 32];
        bytes.copy_from_slice(hash.as_bytes());
        Hash(bytes)
    }
}

/// Generate a new keypair for signing
pub fn generate_keypair() -> Keypair {
    let mut csprng = OsRng{};
    Keypair::generate(&mut csprng)
}

/// Sign data with a private key
pub fn sign(data: &[u8], keypair: &Keypair) -> Signature {
    keypair.sign(data)
}

/// Verify a signature
pub fn verify(data: &[u8], signature: &Signature, public_key: &PublicKey) -> bool {
    public_key.verify(data, signature).is_ok()
}

/// Encrypt data with a public key (simplified)
pub fn encrypt(data: &[u8], public_key: &[u8]) -> Vec<u8> {
    // In a real implementation, use proper hybrid encryption
    // This is just a placeholder
    data.to_vec()
}

/// Decrypt data with a private key (simplified)
pub fn decrypt(encrypted_data: &[u8], private_key: &[u8]) -> Option<Vec<u8>> {
    // In a real implementation, use proper hybrid decryption
    // This is just a placeholder
    Some(encrypted_data.to_vec())
}