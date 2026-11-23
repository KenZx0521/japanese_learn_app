//! §7.2 每日預算。

mod common;

use common::*;
use jp_plan::budget::{
    assess_recovery, estimate_review_minutes, missed_study_days, new_cards_minutes, review_cap,
    review_cap_after_tail, round_half, stage_split, tail_card_limit, NewContentMode, RecoveryFacts,
    RecoveryReason, Split,
};
use jp_plan::calendar::{PlanHistory, ALL_DAYS_MASK};

fn split(new: f64, review: f64, drill: f64, listen: f64) -> Split {
    Split {
        new,
        review,
        drill,
        listen,
    }
}

#[test]
fn every_preset_times_stage_matches_the_table() {
    let table = [
        (10, "st.s0", split(6.0, 4.0, 0.0, 0.0)),
        (10, "st.s1", split(2.5, 4.0, 2.5, 1.0)),
        (10, "st.s2", split(2.0, 6.0, 1.0, 1.0)),
        (10, "st.s3", split(2.0, 4.5, 1.5, 2.0)),
        (20, "st.s0", split(12.0, 8.0, 0.0, 0.0)),
        (20, "st.s1", split(5.0, 8.0, 5.0, 2.0)),
        (20, "st.s2", split(4.0, 9.0, 4.0, 3.0)),
        (20, "st.s3", split(4.0, 9.0, 3.0, 4.0)),
        (30, "st.s0", split(18.0, 12.0, 0.0, 0.0)),
        (30, "st.s1", split(7.5, 12.0, 7.5, 3.0)),
        (30, "st.s2", split(6.0, 14.0, 6.0, 4.0)),
        (30, "st.s3", split(6.0, 13.5, 4.5, 6.0)),
        (45, "st.s0", split(27.0, 18.0, 0.0, 0.0)),
        (45, "st.s1", split(11.5, 17.5, 11.5, 4.5)),
        (45, "st.s2", split(9.0, 20.0, 9.0, 7.0)),
        (45, "st.s3", split(9.0, 20.0, 7.0, 9.0)),
    ];
    let store = content();

    for (minutes, stage, expected) in table {
        assert_eq!(
            stage_split(&preset(&store, minutes), Some(stage)),
            expected,
            "{minutes} {stage}"
        );
    }
}

#[test]
fn split_always_sums_to_the_daily_minutes() {
    let store = content();

    for minutes in [10, 20, 30, 45] {
        for stage in ["st.s0", "st.s1", "st.s2", "st.s3"] {
            let s = stage_split(&preset(&store, minutes), Some(stage));
            assert_eq!(
                s.new + s.review + s.drill + s.listen,
                f64::from(minutes),
                "{minutes} {stage}"
            );
        }
    }
}

#[test]
fn s0_has_no_drill_or_listen_budget() {
    let store = content();
    let s = stage_split(&preset(&store, 20), Some("st.s0"));

    assert_eq!((s.drill, s.listen), (0.0, 0.0));
}

#[test]
fn unknown_stage_falls_back_to_preset_split() {
    let store = content();
    let s = stage_split(&preset(&store, 20), None);

    assert_eq!(s, split(4.0, 9.0, 4.0, 3.0));
}

#[test]
fn round_half_rounds_to_nearest_half_minute() {
    assert_eq!(round_half(11.25), 11.5);
    assert_eq!(round_half(6.74), 6.5);
    assert_eq!(round_half(6.75), 7.0);
    assert_eq!(round_half(0.4), 0.5);
    assert_eq!(round_half(0.24), 0.0);
}

#[test]
fn review_cap_nine_minutes_all_auto_cards() {
    assert_eq!(review_cap(9.0, &due_facets(100, "recog")), 67);
}

#[test]
fn review_cap_nine_minutes_all_use_cards() {
    assert_eq!(review_cap(9.0, &due_facets(100, "use")), 21);
}

#[test]
fn review_cap_with_no_due_cards_converts_all_time_to_auto_cards() {
    assert_eq!(review_cap(9.0, &[]), 67);
}

#[test]
fn review_cap_adds_leftover_time_when_due_cards_run_out() {
    // 2 張自動卡 16 秒，餘 524 秒 / 8 = 65。
    assert_eq!(review_cap(9.0, &due_facets(2, "recog")), 67);
    // 21 張 use 剛好走完，餘 15 秒 / 8 = 1。
    assert_eq!(review_cap(9.0, &due_facets(21, "use")), 22);
}

#[test]
fn review_cap_stops_at_the_first_card_that_does_not_fit() {
    let mut mixed = due_facets(1, "use");
    mixed.extend(due_facets(100, "listen"));

    // 25 + 64 × 8 = 537，下一張 545 超過 540。
    assert_eq!(review_cap(9.0, &mixed), 65);
}

#[test]
fn review_cap_includes_a_card_that_fits_exactly() {
    // 120 秒剛好 15 張自動卡，第 16 張放不下。
    assert_eq!(review_cap(2.0, &due_facets(20, "recog")), 15);
}

#[test]
fn review_cap_is_at_least_one() {
    assert_eq!(review_cap(0.1, &due_facets(5, "recog")), 1);
    assert_eq!(review_cap(0.1, &[]), 1);
    assert_eq!(review_cap(0.0, &due_facets(1, "use")), 1);
}

#[test]
fn review_cap_after_tail_reserves_eight_seconds_per_new_card() {
    // 540 − 3 × 8 = 516 秒 → 64 張；沒有收尾新卡時同 `review_cap`。
    assert_eq!(review_cap_after_tail(9.0, 3, &due_facets(100, "recog")), 64);
    assert_eq!(review_cap_after_tail(9.0, 0, &due_facets(100, "recog")), 67);
}

#[test]
fn review_cap_after_tail_counts_leftover_after_the_reserve() {
    // 1 張 use 25 秒，餘 540 − 40 − 25 = 475 秒 / 8 = 59。
    assert_eq!(review_cap_after_tail(9.0, 5, &due_facets(1, "use")), 60);
}

/// 收尾新卡一天至多用掉 review 秒數的一半（§7.2）：長期無聲後打開聲音、累積上百張 `:listen`
/// 新卡時，`review_cap` 不會塌成 1，T1 預估也不會超過方案分鐘（review_rust R2-H1）。
#[test]
fn tail_card_limit_is_half_of_the_review_seconds_in_auto_cards() {
    // 540 秒的一半 270 秒 / 8 = 33 張；60 秒 → 3 張。
    assert_eq!(tail_card_limit(9.0), 33);
    assert_eq!(tail_card_limit(1.0), 3);
    assert_eq!(tail_card_limit(0.0), 0);
}

#[test]
fn review_cap_after_tail_reserves_at_most_half_of_the_review_seconds() {
    // 收尾 160 張只預留 33 張：540 − 264 = 276 秒 → 11 張 use 卡。
    assert_eq!(review_cap_after_tail(9.0, 160, &due_facets(30, "use")), 11);
    // 60 秒只預留 3 張（24 秒），餘 36 秒：5 張自動卡放得下 4 張；沒有到期卡時 36 / 8 = 4。
    assert_eq!(review_cap_after_tail(1.0, 20, &due_facets(5, "recog")), 4);
    assert_eq!(review_cap_after_tail(1.0, 20, &[]), 4);
}

#[test]
fn estimate_counts_only_cards_within_cap_and_new_cards() {
    // 2 張：8 + 25 = 33 秒，加新卡 3×8 = 24 → 57 秒 ≈ 0.95 分 → 1.0。
    let due = facets(&["recog", "use", "recog"]);
    assert_eq!(estimate_review_minutes(&due, 2, 3), 1.0);
}

#[test]
fn estimate_ignores_cards_beyond_the_cap() {
    let due = facets(&["recog", "use", "use", "use"]);

    // 上限 1 張只算 8 秒，後面 3 張 use 不計。
    assert_eq!(estimate_review_minutes(&due, 1, 0), 0.0);
}

#[test]
fn estimate_of_nothing_is_zero() {
    assert_eq!(estimate_review_minutes(&[], 10, 0), 0.0);
}

#[test]
fn new_cards_minutes_rounds_to_half() {
    assert_eq!(new_cards_minutes(0), 0.0);
    assert_eq!(new_cards_minutes(3), 0.5);
    assert_eq!(new_cards_minutes(15), 2.0);
}

fn everyday_history() -> PlanHistory {
    PlanHistory::from_rows(&[plan_row(d("2026-01-01"), 20, ALL_DAYS_MASK)])
}

#[test]
fn missed_days_counts_only_scheduled_days_between_last_active_and_today() {
    let history = everyday_history();

    assert_eq!(
        missed_study_days(Some(d("2026-03-01")), d("2026-03-05"), &history),
        3
    );
    assert_eq!(
        missed_study_days(Some(d("2026-03-04")), d("2026-03-05"), &history),
        0
    );
}

#[test]
fn missed_days_ignores_rest_days() {
    let history = PlanHistory::from_rows(&[plan_row(d("2026-01-01"), 20, MWF_MASK)]);

    // 03-02（一）活躍，到 03-09（一）之間排定 03-04、03-06 兩天。
    assert_eq!(
        missed_study_days(Some(d("2026-03-02")), d("2026-03-09"), &history),
        2
    );
}

#[test]
fn missed_days_with_no_activity_is_zero() {
    assert_eq!(
        missed_study_days(None, d("2026-03-05"), &everyday_history()),
        0
    );
}

fn facts() -> RecoveryFacts {
    RecoveryFacts {
        due_reviews: 0,
        review_cap: 67,
        capacity: 67,
        tail_new_cards: 0,
        unseen_new: 0,
        new_words_limit: 5,
        missed_study_days: 0,
        previous_recovery_days: 0,
        is_study_day: true,
    }
}

#[test]
fn unrestricted_day_is_full_and_resets_recovery_days() {
    let r = assess_recovery(&RecoveryFacts {
        previous_recovery_days: 5,
        ..facts()
    });

    assert_eq!(r.reason, None);
    assert_eq!(r.days, 0);
    assert_eq!(r.mode, NewContentMode::Full);
    assert_eq!(r.review_cap, 67);
}

#[test]
fn backlog_needs_more_than_twice_the_cap() {
    let at_limit = assess_recovery(&RecoveryFacts {
        due_reviews: 134,
        ..facts()
    });
    let over = assess_recovery(&RecoveryFacts {
        due_reviews: 135,
        ..facts()
    });

    assert_eq!(at_limit.reason, None);
    assert_eq!(over.reason, Some(RecoveryReason::ReviewBacklog));
    assert_eq!(over.days, 1);
    assert_eq!(over.mode, NewContentMode::None);
    assert_eq!(over.review_cap, 67);
}

#[test]
fn unseen_new_cards_needs_more_than_the_limit() {
    let at_limit = assess_recovery(&RecoveryFacts {
        unseen_new: 5,
        ..facts()
    });
    let over = assess_recovery(&RecoveryFacts {
        unseen_new: 6,
        ..facts()
    });

    assert_eq!(at_limit.reason, None);
    assert_eq!(over.reason, Some(RecoveryReason::UnseenNewCards));
}

#[test]
fn return_after_break_needs_three_missed_days_and_halves_the_cap() {
    let two = assess_recovery(&RecoveryFacts {
        missed_study_days: 2,
        ..facts()
    });
    let three = assess_recovery(&RecoveryFacts {
        missed_study_days: 3,
        due_reviews: 1,
        ..facts()
    });

    assert_eq!(two.reason, None);
    assert_eq!(three.reason, Some(RecoveryReason::ReturnAfterBreak));
    assert_eq!(three.days, 1);
    assert_eq!(three.mode, NewContentMode::None);
    assert_eq!(three.review_cap, 33);
}

#[test]
fn halved_cap_is_at_least_one() {
    let r = assess_recovery(&RecoveryFacts {
        missed_study_days: 3,
        due_reviews: 1,
        review_cap: 1,
        ..facts()
    });

    assert_eq!(r.review_cap, 1);
}

#[test]
fn return_after_break_outranks_others_and_fixes_days_at_one() {
    let r = assess_recovery(&RecoveryFacts {
        missed_study_days: 4,
        due_reviews: 500,
        unseen_new: 99,
        previous_recovery_days: 6,
        ..facts()
    });

    assert_eq!(r.reason, Some(RecoveryReason::ReturnAfterBreak));
    assert_eq!(r.days, 1);
    assert_eq!(r.mode, NewContentMode::None);
}

#[test]
fn backlog_outranks_unseen_new_cards() {
    let r = assess_recovery(&RecoveryFacts {
        due_reviews: 500,
        unseen_new: 99,
        ..facts()
    });

    assert_eq!(r.reason, Some(RecoveryReason::ReviewBacklog));
}

#[test]
fn backlog_over_the_pause_line_withholds_new_content_on_any_day() {
    // cap 67：2 倍 134、5 倍 335。
    let day = |due, previous| {
        assess_recovery(&RecoveryFacts {
            due_reviews: due,
            previous_recovery_days: previous,
            ..facts()
        })
    };

    let over = day(336, 5);

    assert_eq!(over.reason, Some(RecoveryReason::ReviewBacklog));
    assert_eq!(over.days, 6);
    assert_eq!(over.mode, NewContentMode::None);
    assert_eq!(over.review_cap, 67);
}

#[test]
fn backlog_up_to_the_pause_line_keeps_minimal_from_day_three() {
    let day = |due, previous| {
        assess_recovery(&RecoveryFacts {
            due_reviews: due,
            previous_recovery_days: previous,
            ..facts()
        })
    };

    assert_eq!(day(335, 1).mode, NewContentMode::None);
    assert_eq!(day(335, 2).mode, NewContentMode::Minimal);
    assert_eq!(day(135, 7).mode, NewContentMode::Minimal);
}

/// `review_cap` 已扣收尾新卡；積壓的兩條線看扣除前的 `capacity`（RULINGS O11）。
#[test]
fn backlog_lines_compare_against_the_capacity_before_the_tail() {
    let day = |due, previous| {
        assess_recovery(&RecoveryFacts {
            due_reviews: due,
            review_cap: 60,
            previous_recovery_days: previous,
            ..facts()
        })
    };

    assert_eq!(day(134, 0).reason, None);
    assert_eq!(day(135, 0).reason, Some(RecoveryReason::ReviewBacklog));
    assert_eq!(day(335, 5).mode, NewContentMode::Minimal);
    assert_eq!(day(336, 5).mode, NewContentMode::None);
    assert_eq!(day(336, 5).review_cap, 60);
}

#[test]
fn other_reasons_ignore_the_pause_line() {
    // 回鍋當天本來就是 None；未看完的新卡第 3 天起 Minimal，到期數多寡不影響。
    let unseen = assess_recovery(&RecoveryFacts {
        due_reviews: 134,
        unseen_new: 99,
        previous_recovery_days: 4,
        ..facts()
    });

    assert_eq!(unseen.reason, Some(RecoveryReason::UnseenNewCards));
    assert_eq!(unseen.mode, NewContentMode::Minimal);
}

/// 積壓旗標看到期數（`due > 2 × capacity`），不看原因標籤（RULINGS O12）。
#[test]
fn backlog_flag_follows_the_due_count_not_the_reason() {
    let with = |change: fn(RecoveryFacts) -> RecoveryFacts| assess_recovery(&change(facts()));

    let backlog = with(|f| RecoveryFacts {
        due_reviews: 135,
        ..f
    });
    let unseen = with(|f| RecoveryFacts { unseen_new: 6, ..f });
    let back_with_backlog = with(|f| RecoveryFacts {
        missed_study_days: 3,
        due_reviews: 135,
        ..f
    });
    let back_without = with(|f| RecoveryFacts {
        missed_study_days: 3,
        due_reviews: 134,
        ..f
    });

    assert!(backlog.backlog);
    assert!(!unseen.backlog);
    assert!(back_with_backlog.backlog);
    assert!(!back_without.backlog);
    assert!(!with(|f| f).backlog);
}

/// 只剩收尾新卡時有事可做（T1 的「收尾」列），回鍋照舊。
#[test]
fn tail_new_cards_alone_are_enough_for_a_return_after_break() {
    let r = assess_recovery(&RecoveryFacts {
        missed_study_days: 3,
        tail_new_cards: 1,
        ..facts()
    });

    assert_eq!(r.reason, Some(RecoveryReason::ReturnAfterBreak));
    assert_eq!(r.days, 1);
}

/// 積壓判定看扣收尾前的 `capacity`，不看已扣收尾的 `review_cap`（RULINGS O11、review_rc RC7）。
#[test]
fn backlog_flag_compares_the_due_count_against_the_capacity_not_the_cap() {
    let day = |due| {
        assess_recovery(&RecoveryFacts {
            due_reviews: due,
            review_cap: 40,
            ..facts()
        })
    };

    assert!(
        !day(134).backlog,
        "超過 2 × review_cap，但沒超過 2 × capacity"
    );
    assert!(day(135).backlog);
}

/// 回鍋日到期數 > 2 × `capacity`：原因仍記 `ReturnAfterBreak`，只排複習，`review_cap` 仍減半。
#[test]
fn return_after_break_with_backlog_only_reviews_and_keeps_the_half_cap() {
    let r = assess_recovery(&RecoveryFacts {
        missed_study_days: 3,
        due_reviews: 300,
        ..facts()
    });

    assert_eq!(r.reason, Some(RecoveryReason::ReturnAfterBreak));
    assert_eq!(r.mode, NewContentMode::None);
    assert!(r.reviews_only());
    assert_eq!(r.review_cap, 33);
}

#[test]
fn return_after_break_under_the_backlog_line_keeps_the_stage_split() {
    let r = assess_recovery(&RecoveryFacts {
        missed_study_days: 3,
        due_reviews: 134,
        ..facts()
    });

    assert!(!r.reviews_only());
}

/// 換成合併後的 `review_cap` 時，回鍋日照樣減半；其他日子原樣。
#[test]
fn with_review_cap_halves_only_on_a_return_day() {
    let back = assess_recovery(&RecoveryFacts {
        missed_study_days: 3,
        due_reviews: 300,
        ..facts()
    });
    let backlog = assess_recovery(&RecoveryFacts {
        due_reviews: 300,
        ..facts()
    });

    assert_eq!(back.with_review_cap(150).review_cap, 75);
    assert_eq!(back.with_review_cap(1).review_cap, 1);
    assert_eq!(backlog.with_review_cap(150).review_cap, 150);
}

/// 休息日不遞增 `recovery_days`，維持前一筆快照的值（RULINGS O12）。
#[test]
fn rest_day_keeps_the_previous_recovery_days() {
    let rest = |due, previous| {
        assess_recovery(&RecoveryFacts {
            due_reviews: due,
            previous_recovery_days: previous,
            is_study_day: false,
            ..facts()
        })
    };

    let backlog = rest(135, 2);
    assert_eq!(backlog.reason, Some(RecoveryReason::ReviewBacklog));
    assert_eq!(backlog.days, 2);
    assert_eq!(backlog.mode, NewContentMode::None);
    assert_eq!(rest(135, 0).days, 0);
    assert_eq!(rest(135, 0).mode, NewContentMode::None);
    assert_eq!(rest(135, 4).mode, NewContentMode::Minimal);
    assert_eq!(
        (rest(0, 4).days, rest(0, 4).mode),
        (4, NewContentMode::Full)
    );
}

/// 回鍋落在休息日：`recovery_days` 歸 0，下個學習日從 1 起算，
/// 否則缺席前的舊值帶過整段缺席，直接跳過「前 2 天不給新內容」（review_rc RC4）。
#[test]
fn rest_day_return_after_break_restarts_recovery_days() {
    let r = assess_recovery(&RecoveryFacts {
        missed_study_days: 3,
        due_reviews: 1,
        previous_recovery_days: 2,
        is_study_day: false,
        ..facts()
    });

    assert_eq!(r.reason, Some(RecoveryReason::ReturnAfterBreak));
    assert_eq!(r.days, 0);
    assert_eq!(r.mode, NewContentMode::None);
}

/// 休息日回鍋照樣減半：回鍋日本來就該輕，休息日只是不併入方案分鐘（RULINGS O12）。
#[test]
fn rest_day_return_after_break_still_halves_the_cap() {
    let r = assess_recovery(&RecoveryFacts {
        missed_study_days: 3,
        due_reviews: 300,
        is_study_day: false,
        ..facts()
    });

    assert_eq!(r.review_cap, 33);
    assert!(!r.reviews_only());
}

/// 缺席夠久但今天沒有任何卡可碰：不算回鍋，否則今天做不了事、不會變成活躍日，天天判回鍋（review_rc RC1）。
#[test]
fn nothing_to_review_is_not_a_return_after_break() {
    let r = assess_recovery(&RecoveryFacts {
        missed_study_days: 9,
        ..facts()
    });

    assert_eq!(r.reason, None);
    assert_eq!(r.days, 0);
    assert_eq!(r.mode, NewContentMode::Full);
    assert_eq!(r.review_cap, 67);
}

/// 休息日只列 `Review`，複習上限用階段配比，不把方案分鐘全部併入（RULINGS O12）。
#[test]
fn rest_day_backlog_does_not_merge_into_review() {
    let r = assess_recovery(&RecoveryFacts {
        due_reviews: 300,
        is_study_day: false,
        ..facts()
    });

    assert!(r.backlog);
    assert!(!r.reviews_only());
    assert_eq!(r.review_cap, 67);
}

#[test]
fn recovery_days_continue_and_switch_to_minimal_on_day_three() {
    let day = |previous| {
        assess_recovery(&RecoveryFacts {
            unseen_new: 99,
            previous_recovery_days: previous,
            ..facts()
        })
    };

    assert_eq!((day(0).days, day(0).mode), (1, NewContentMode::None));
    assert_eq!((day(1).days, day(1).mode), (2, NewContentMode::None));
    assert_eq!((day(2).days, day(2).mode), (3, NewContentMode::Minimal));
    assert_eq!((day(7).days, day(7).mode), (8, NewContentMode::Minimal));
}
