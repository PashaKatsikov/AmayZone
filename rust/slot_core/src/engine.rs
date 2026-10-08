use crate::model::{Model, BONUS, REELS, ROWS, WILD};

#[repr(C)]
#[derive(Clone, Copy, Default, Debug)]
pub struct SpinResult {
    /// Column-major: `grid[reel * ROWS + row]`.
    pub grid: [u8; REELS * ROWS],
    /// Bit `reel * ROWS + row` is set for cells that take part in a win.
    pub win_mask: u32,
    /// Total payout in coins, free-spin multiplier already applied.
    pub win: u64,
    pub free_spins: u8,
    pub scatters: u8,
    /// Longest run of reels hit by any paying symbol (0 when nothing paid).
    pub best_run: u8,
    pub _pad: u8,
}

pub trait Source {
    fn below(&mut self, bound: u32) -> u32;
}

pub struct OsSource;

impl Source for OsSource {
    fn below(&mut self, bound: u32) -> u32 {
        debug_assert!(bound > 0);
        // Rejection sampling keeps the distribution flat for any strip length.
        let zone = u32::MAX - (u32::MAX % bound);
        loop {
            let mut b = [0u8; 4];
            if getrandom::getrandom(&mut b).is_err() {
                // Entropy source failing is not recoverable for a fair game.
                std::process::abort();
            }
            let v = u32::from_le_bytes(b);
            if v < zone {
                return v % bound;
            }
        }
    }
}

pub fn spin(model: &Model, src: &mut dyn Source, bet: u64, free_mode: bool) -> SpinResult {
    let mut res = SpinResult::default();

    for r in 0..REELS {
        let strip = &model.reels[r];
        let stop = src.below(strip.len() as u32) as usize;
        for row in 0..ROWS {
            res.grid[r * ROWS + row] = strip[(stop + row) % strip.len()];
        }
    }
    evaluate(model, &mut res, bet, free_mode);
    res
}

pub fn evaluate(model: &Model, res: &mut SpinResult, bet: u64, free_mode: bool) {
    let mult = if free_mode { model.free_mult as u64 } else { 1 };
    let mut thousandths: u64 = 0;
    let mut mask = 0u32;

    let cell = |reel: usize, row: usize| res.grid[reel * ROWS + row];

    // Ways to win: left to right, adjacent reels, wild substitutes everything
    // except the bonus symbol.
    for sym in 0..WILD {
        let mut ways = 1u64;
        let mut run = 0usize;
        for reel in 0..REELS {
            let hits = (0..ROWS)
                .filter(|&row| {
                    let c = cell(reel, row);
                    c == sym || c == WILD
                })
                .count() as u64;
            if hits == 0 {
                break;
            }
            ways *= hits;
            run += 1;
        }
        if run < 3 {
            continue;
        }
        let pay = model.pays[sym as usize][run - 3] as u64;
        if pay == 0 {
            continue;
        }
        thousandths += pay * ways;
        res.best_run = res.best_run.max(run as u8);
        for reel in 0..run {
            for row in 0..ROWS {
                let c = cell(reel, row);
                if c == sym || c == WILD {
                    mask |= 1 << (reel * ROWS + row);
                }
            }
        }
    }

    let mut scatters = 0u8;
    for reel in 0..REELS {
        for row in 0..ROWS {
            if cell(reel, row) == BONUS {
                scatters += 1;
                mask |= 1 << (reel * ROWS + row);
            }
        }
    }
    res.scatters = scatters;
    if scatters >= 3 {
        let tier = (scatters.min(5) - 3) as usize;
        thousandths += model.scatter_pay[tier] as u64;
        res.free_spins = model.free_spins[tier];
    } else {
        // A pair of bonus symbols pays nothing, so don't highlight them.
        for reel in 0..REELS {
            for row in 0..ROWS {
                if cell(reel, row) == BONUS {
                    mask &= !(1 << (reel * ROWS + row));
                }
            }
        }
    }

    res.win_mask = mask;
    res.win = bet * thousandths / 1000 * mult;
}
