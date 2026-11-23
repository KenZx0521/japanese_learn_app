//! rust-core.md §8.1 的黃金值。任何一個變動都代表題目順序跨版本不穩定。

use jp_lang::quiz::rng::{fnv1a, index_below, rng_from_seed, seed_for, shuffled};
use rand_chacha::rand_core::RngCore;

const LETTERS: [&str; 6] = ["A", "B", "C", "D", "E", "F"];

#[test]
fn fnv1a_matches_golden_value() {
    assert_eq!(fnv1a("vo.taberu:recog"), 3117249249664061045);
}

#[test]
fn chacha8_matches_golden_value() {
    assert_eq!(rng_from_seed(0).next_u64(), 13080132717333068652);
}

#[test]
fn shuffle_matches_golden_order() {
    let mut rng = rng_from_seed(seed_for(42, "vo.taberu:recog"));
    assert_eq!(
        shuffled(&mut rng, LETTERS.to_vec()),
        ["B", "A", "F", "D", "E", "C"]
    );
}

#[test]
fn seed_for_xors_session_seed_with_hash() {
    let hash = fnv1a("vo.taberu:recog");
    assert_eq!(seed_for(42, "vo.taberu:recog"), 42 ^ hash);
    assert_eq!(seed_for(0, "vo.taberu:recog"), hash);
}

#[test]
fn same_seed_gives_same_sequence_and_different_seed_differs() {
    let run = |seed| shuffled(&mut rng_from_seed(seed), (0..32).collect::<Vec<_>>());
    assert_eq!(run(7), run(7));
    assert_ne!(run(7), run(8));
}

#[test]
fn shuffle_keeps_every_item() {
    let items: Vec<u32> = (0..100).collect();
    let mut out = shuffled(&mut rng_from_seed(5), items.clone());
    out.sort_unstable();
    assert_eq!(out, items);
}

#[test]
fn shuffle_handles_empty_and_single_item() {
    assert_eq!(
        shuffled(&mut rng_from_seed(1), Vec::<u8>::new()),
        Vec::<u8>::new()
    );
    assert_eq!(shuffled(&mut rng_from_seed(1), vec![9]), vec![9]);
}

#[test]
fn index_below_stays_in_range_and_rejects_zero() {
    let mut rng = rng_from_seed(3);
    assert_eq!(index_below(&mut rng, 0), None);
    assert_eq!(index_below(&mut rng, 1), Some(0));
    for _ in 0..1000 {
        assert!(index_below(&mut rng, 7).is_some_and(|i| i < 7));
    }
}

#[test]
fn index_below_is_roughly_uniform() {
    let mut rng = rng_from_seed(11);
    let mut counts = [0u32; 4];
    for _ in 0..8000 {
        counts[index_below(&mut rng, 4).expect("上限非零")] += 1;
    }
    assert!(
        counts.iter().all(|&c| (1800..=2200).contains(&c)),
        "{counts:?}"
    );
}
