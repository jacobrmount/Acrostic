extern crate cbindgen;

use std::env;
use std::path::PathBuf;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let out_dir = PathBuf::from(crate_dir.clone());
    
    // Generate C header
    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_language(cbindgen::Language::C)
        .generate()
        .expect("Unable to generate C bindings")
        .write_to_file(out_dir.join("include/acrostic_storage.h"));
        
    // Build for iOS if targeting iOS
    if env::var("TARGET").unwrap_or_default().contains("ios") {
        println!("cargo:rustc-link-lib=framework=Security");
    }
}