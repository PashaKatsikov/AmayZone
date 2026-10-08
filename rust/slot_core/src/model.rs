use chacha20poly1305::aead::{Aead, KeyInit};
use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce};

include!(concat!(env!("OUT_DIR"), "/keys.rs"));

static SEALED: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/model.bin"));

pub const REELS: usize = 5;
pub const ROWS: usize = 4;
pub const SYMBOLS: usize = 14;
pub const WILD: u8 = 12;
pub const BONUS: u8 = 13;

pub struct Model {
    pub reels: [Vec<u8>; REELS],
    /// Pay per way for 3/4/5 of a kind, in thousandths of the total bet.
    pub pays: [[u32; 3]; SYMBOLS],
    pub scatter_pay: [u32; 3],
    pub free_spins: [u8; 3],
    pub free_mult: u8,
}

#[derive(Debug)]
pub enum ModelError {
    Decrypt,
    Corrupt,
}

impl Model {
    pub fn load() -> Result<Model, ModelError> {
        let mut key = [0u8; 32];
        for i in 0..32 {
            key[i] = SHARE_A[i] ^ SHARE_B[i];
        }
        let cipher = ChaCha20Poly1305::new(Key::from_slice(&key));
        let raw = cipher
            .decrypt(Nonce::from_slice(&NONCE), SEALED)
            .map_err(|_| ModelError::Decrypt)?;
        Model::parse(&raw)
    }

    fn parse(raw: &[u8]) -> Result<Model, ModelError> {
        let mut rd = Reader { raw, at: 0 };
        if rd.take(4)? != b"AZM1" {
            return Err(ModelError::Corrupt);
        }
        let mut reels: [Vec<u8>; REELS] = Default::default();
        for reel in reels.iter_mut() {
            let len = rd.take(1)?[0] as usize;
            let syms = rd.take(len)?;
            if syms.iter().any(|s| *s as usize >= SYMBOLS) {
                return Err(ModelError::Corrupt);
            }
            *reel = syms.to_vec();
        }
        let mut pays = [[0u32; 3]; SYMBOLS];
        for p in pays.iter_mut() {
            for v in p.iter_mut() {
                *v = rd.word()?;
            }
        }
        let mut scatter_pay = [0u32; 3];
        for v in scatter_pay.iter_mut() {
            *v = rd.word()?;
        }
        let fs = rd.take(3)?;
        let free_spins = [fs[0], fs[1], fs[2]];
        let free_mult = rd.take(1)?[0].max(1);
        Ok(Model {
            reels,
            pays,
            scatter_pay,
            free_spins,
            free_mult,
        })
    }
}

struct Reader<'a> {
    raw: &'a [u8],
    at: usize,
}

impl<'a> Reader<'a> {
    fn take(&mut self, n: usize) -> Result<&'a [u8], ModelError> {
        let s = self
            .raw
            .get(self.at..self.at + n)
            .ok_or(ModelError::Corrupt)?;
        self.at += n;
        Ok(s)
    }

    fn word(&mut self) -> Result<u32, ModelError> {
        let b = self.take(4)?;
        Ok(u32::from_le_bytes([b[0], b[1], b[2], b[3]]))
    }
}
