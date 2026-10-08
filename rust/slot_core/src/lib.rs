//! Slot math core. The paytable and reel strips are compiled in encrypted form
//! and only decrypted into memory on first use.

mod engine;
mod model;

use engine::{OsSource, SpinResult};
use model::Model;
use std::sync::OnceLock;

static MODEL: OnceLock<Option<Model>> = OnceLock::new();

fn model() -> Option<&'static Model> {
    MODEL.get_or_init(|| Model::load().ok()).as_ref()
}

/// Returns 0 when the math model was decrypted and validated.
#[no_mangle]
pub extern "C" fn az_init() -> i32 {
    if model().is_some() {
        0
    } else {
        -1
    }
}

/// # Safety
/// `out` must point to a writable `SpinResult`.
#[no_mangle]
pub unsafe extern "C" fn az_spin(bet: u64, free_mode: u32, out: *mut SpinResult) -> i32 {
    if out.is_null() || bet == 0 {
        return -2;
    }
    let Some(m) = model() else { return -1 };
    *out = engine::spin(m, &mut OsSource, bet, free_mode != 0);
    0
}

/// Pay per way for `count` (3..=5) matching reels, in thousandths of the bet.
/// For the bonus symbol (13) this is the scatter pay.
#[no_mangle]
pub extern "C" fn az_pay(symbol: u32, count: u32) -> u32 {
    let Some(m) = model() else { return 0 };
    if !(3..=5).contains(&count) || symbol as usize >= model::SYMBOLS {
        return 0;
    }
    let tier = (count - 3) as usize;
    if symbol as u8 == model::BONUS {
        m.scatter_pay[tier]
    } else {
        m.pays[symbol as usize][tier]
    }
}

#[no_mangle]
pub extern "C" fn az_free_spins(scatters: u32) -> u32 {
    match model() {
        Some(m) if (3..=5).contains(&scatters) => m.free_spins[(scatters - 3) as usize] as u32,
        _ => 0,
    }
}

#[no_mangle]
pub extern "C" fn az_free_multiplier() -> u32 {
    model().map(|m| m.free_mult as u32).unwrap_or(1)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::engine::Source;

    struct Fixed(Vec<u32>, usize);
    impl Source for Fixed {
        fn below(&mut self, bound: u32) -> u32 {
            let v = self.0[self.1 % self.0.len()] % bound;
            self.1 += 1;
            v
        }
    }

    #[test]
    fn model_decrypts() {
        assert_eq!(az_init(), 0);
    }

    #[test]
    fn deterministic_stops_give_stable_grid() {
        let m = model().unwrap();
        let a = engine::spin(m, &mut Fixed(vec![0, 1, 2, 3, 4], 0), 1000, false);
        let b = engine::spin(m, &mut Fixed(vec![0, 1, 2, 3, 4], 0), 1000, false);
        assert_eq!(a.grid, b.grid);
        assert_eq!(a.win, b.win);
    }

    /// Run with: cargo test --release simulate -- --ignored --nocapture
    #[test]
    #[ignore]
    fn simulate() {
        let m = model().unwrap();
        let mut src = OsSource;
        let n: u64 = 20_000_000;
        let bet = 1000u64;
        let (mut base_win, mut hits, mut triggers, mut max) = (0u64, 0u64, 0u64, 0u64);
        let mut free_win = 0u64;
        let mut free_spins_total = 0u64;
        let mut big = 0u64;
        for _ in 0..n {
            let r = engine::spin(m, &mut src, bet, false);
            base_win += r.win;
            if r.win > 0 {
                hits += 1;
            }
            max = max.max(r.win);
            if r.win >= bet * 10 {
                big += 1;
            }
            if r.free_spins > 0 {
                triggers += 1;
                // Play the feature out, retriggers included.
                let mut left = r.free_spins as u64;
                while left > 0 {
                    left -= 1;
                    free_spins_total += 1;
                    let f = engine::spin(m, &mut src, bet, true);
                    free_win += f.win;
                    max = max.max(f.win);
                    left += f.free_spins as u64;
                }
            }
        }
        let total = (base_win + free_win) as f64;
        let wagered = (n * bet) as f64;
        println!("base RTP      {:.2}%", base_win as f64 / wagered * 100.0);
        println!("feature RTP   {:.2}%", free_win as f64 / wagered * 100.0);
        println!("total RTP     {:.2}%", total / wagered * 100.0);
        println!("hit rate      {:.2}%", hits as f64 / n as f64 * 100.0);
        println!("bonus freq    1 in {:.0}", n as f64 / triggers.max(1) as f64);
        println!("avg fs/trig   {:.1}", free_spins_total as f64 / triggers.max(1) as f64);
        println!("10x+ wins     1 in {:.0}", n as f64 / big.max(1) as f64);
        println!("max win       {}x", max as f64 / bet as f64);
    }
}
