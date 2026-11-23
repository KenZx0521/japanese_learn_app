//! 確定性亂數（rust-core.md §8.1）。
//!
//! 不用 `rand` 的 `shuffle`，也不用 `DefaultHasher`：兩者都不保證跨版本的數值穩定，
//! 黃金測試會壞，同一天重開畫面的題目也會變。

use rand_chacha::rand_core::{RngCore, SeedableRng};

pub use rand_chacha::ChaCha8Rng;

const FNV_OFFSET_BASIS: u64 = 0xcbf2_9ce4_8422_2325;
const FNV_PRIME: u64 = 0x0000_0100_0000_01b3;

/// FNV-1a 64 位元雜湊。
pub fn fnv1a(text: &str) -> u64 {
    text.bytes().fold(FNV_OFFSET_BASIS, |hash, byte| {
        (hash ^ u64::from(byte)).wrapping_mul(FNV_PRIME)
    })
}

/// 由 session 種子與卡片 ID 導出每題的種子。
pub fn seed_for(session_seed: u32, card_id: &str) -> u64 {
    u64::from(session_seed) ^ fnv1a(card_id)
}

pub fn rng_from_seed(seed: u64) -> ChaCha8Rng {
    ChaCha8Rng::seed_from_u64(seed)
}

/// 回傳 `0..bound` 內的均勻整數；`bound` 為 0 時回傳 `None`。
pub fn index_below(rng: &mut ChaCha8Rng, bound: usize) -> Option<usize> {
    let bound_u64 = u64::try_from(bound).ok().filter(|&b| b > 0)?;
    usize::try_from(unbiased_below(rng, bound_u64)).ok()
}

/// Fisher-Yates 洗牌，回傳新的排列。
pub fn shuffled<T>(rng: &mut ChaCha8Rng, items: Vec<T>) -> Vec<T> {
    let mut out = items;
    for i in (1..out.len()).rev() {
        // i + 1 ≤ out.len()，必定可轉成 u64，轉換後也必定落在 usize 範圍內
        let j = unbiased_below(rng, i as u64 + 1) as usize;
        out.swap(i, j);
    }
    out
}

/// 取餘前先排除偏差區間，`bound` 必須大於 0。
fn unbiased_below(rng: &mut ChaCha8Rng, bound: u64) -> u64 {
    let zone = u64::MAX - (u64::MAX % bound);
    loop {
        let value = rng.next_u64();
        if value < zone {
            return value % bound;
        }
    }
}
