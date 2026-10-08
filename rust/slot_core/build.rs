//! Reads the plain-text math model, packs it into a compact binary form and
//! encrypts it with a per-build key. Only the ciphertext ends up in the shared
//! library; the model file itself is never shipped.

use chacha20poly1305::aead::{Aead, KeyInit};
use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;

const SYMBOLS: [&str; 14] = [
    "TEN", "J", "Q", "K", "A", "CHERRY", "BELL", "BAR", "DIAMOND", "CHIPS", "CROWN", "COIN",
    "WILD", "BONUS",
];
const REELS: usize = 5;

fn main() {
    println!("cargo:rerun-if-changed=math/model.txt");
    println!("cargo:rerun-if-changed=build.rs");

    let text = fs::read_to_string("math/model.txt").expect("math/model.txt is missing");
    let ids: HashMap<&str, u8> = SYMBOLS
        .iter()
        .enumerate()
        .map(|(i, s)| (*s, i as u8))
        .collect();

    let mut reels: Vec<Vec<u8>> = vec![Vec::new(); REELS];
    let mut pays = [[0u32; 3]; 14];
    let mut scatter_pay = [0u32; 3];
    let mut free_spins = [0u8; 3];
    let mut free_mult = 1u8;

    for (n, raw) in text.lines().enumerate() {
        let line = raw.split('#').next().unwrap().trim();
        if line.is_empty() {
            continue;
        }
        let (key, value) = line
            .split_once('=')
            .unwrap_or_else(|| panic!("model.txt:{}: expected key = value", n + 1));
        let key = key.trim();
        let nums = || -> Vec<u32> {
            value
                .split_whitespace()
                .map(|v| v.parse().expect("bad number in model"))
                .collect()
        };
        if let Some(idx) = key.strip_prefix("reel") {
            let i: usize = idx.trim().parse::<usize>().expect("bad reel index") - 1;
            reels[i] = value
                .split_whitespace()
                .map(|s| *ids.get(s).unwrap_or_else(|| panic!("unknown symbol {s}")))
                .collect();
        } else if let Some(sym) = key.strip_prefix("pay ") {
            let id = *ids.get(sym.trim()).expect("unknown symbol in pay");
            let v = nums();
            pays[id as usize] = [v[0], v[1], v[2]];
        } else if key == "scatter_pay" {
            let v = nums();
            scatter_pay = [v[0], v[1], v[2]];
        } else if key == "free_spins" {
            let v = nums();
            free_spins = [v[0] as u8, v[1] as u8, v[2] as u8];
        } else if key == "free_multiplier" {
            free_mult = nums()[0] as u8;
        } else {
            panic!("model.txt:{}: unknown key {key}", n + 1);
        }
    }

    let mut blob = Vec::new();
    blob.extend_from_slice(b"AZM1");
    for r in &reels {
        assert!(r.len() >= 8 && r.len() < 256, "reel length out of range");
        blob.push(r.len() as u8);
        blob.extend_from_slice(r);
    }
    for p in &pays {
        for v in p {
            blob.extend_from_slice(&v.to_le_bytes());
        }
    }
    for v in &scatter_pay {
        blob.extend_from_slice(&v.to_le_bytes());
    }
    blob.extend_from_slice(&free_spins);
    blob.push(free_mult);

    let mut key = [0u8; 32];
    let mut nonce = [0u8; 12];
    let mut mask = [0u8; 32];
    getrandom::getrandom(&mut key).unwrap();
    getrandom::getrandom(&mut nonce).unwrap();
    getrandom::getrandom(&mut mask).unwrap();

    let cipher = ChaCha20Poly1305::new(Key::from_slice(&key));
    let sealed = cipher
        .encrypt(Nonce::from_slice(&nonce), blob.as_ref())
        .expect("encryption failed");

    // The key is split in two shares so it never appears as one literal.
    let share_b: Vec<u8> = key.iter().zip(mask.iter()).map(|(k, m)| k ^ m).collect();

    let out = PathBuf::from(env::var("OUT_DIR").unwrap());
    fs::write(out.join("model.bin"), sealed).unwrap();
    let consts = format!(
        "pub(crate) const NONCE: [u8; 12] = {:?};\npub(crate) const SHARE_A: [u8; 32] = {:?};\npub(crate) const SHARE_B: [u8; 32] = {:?};\n",
        nonce, mask, share_b
    );
    fs::write(out.join("keys.rs"), consts).unwrap();
}
