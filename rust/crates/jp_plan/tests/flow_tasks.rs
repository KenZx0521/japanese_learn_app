//! §7.4 今日任務流程，用真實 SQLite（整合日與檢定）。

mod common;

use chrono::{Duration, NaiveDate};
use common::flow::*;
use common::*;
use jp_content::ContentStore;
use jp_lang::clock::DayContext;
use jp_plan::calendar::ALL_DAYS_MASK;
use jp_plan::input::{PlanInput, StartLevel};
use jp_plan::tasks::DailyTask;
use jp_plan::today::{dismiss_checkpoint, today_slice_done, TodayView};
use jp_plan::PlanError;
use jp_store::{ActivityRepo, MilestoneResultRow, PlanRepo, SqliteRepository, SrsRepo};

mod integration_and_checkpoint {
    use super::*;

    fn setup_at(
        lesson: &str,
        minutes: u32,
    ) -> (SqliteRepository, ContentStore, jp_plan::PlanInput) {
        let (repo, store) = (repo(), content());
        let ctx = ctx_on(monday());
        let known = store
            .course()
            .order
            .iter()
            .take_while(|id| id.as_str() != lesson)
            .filter(|id| jp_plan::input::is_kana_lesson(id))
            .cloned()
            .collect();
        let plan = PlanInput {
            known_kana_lessons: known,
            ..input(minutes)
        };
        create_plan(&repo, &store, &ctx, &plan);
        (repo, store, plan)
    }

    fn complete_all(repo: &SqliteRepository, store: &ContentStore, on: NaiveDate) {
        let got = view(repo, store, on);
        for key in keys(&got) {
            done(repo, store, on, key);
        }
    }

    #[test]
    fn known_lessons_are_skipped_on_create() {
        let (repo, store, _) = setup_at("le.l01", 20);

        let got = view(&repo, &store, monday());

        let progress = repo.lesson_progress().unwrap();
        assert!(progress["le.k01"].skipped);
        assert!(got.tasks.iter().any(
            |t| matches!(&t.task, DailyTask::NewContent { lesson_id, .. } if lesson_id == "le.l01")
        ));
    }

    #[test]
    fn vocab_slice_intros_and_inserts_cards() {
        let (repo, store, _) = setup_at("le.l01", 20);
        let today = monday();
        let key = new_key(&view(&repo, &store, today));

        done(&repo, &store, today, &key);

        assert!(repo.card("vo.watashi:recog").unwrap().is_some());
        assert!(repo.card("gr.desu:use").unwrap().is_some());
        assert!(repo.introduced_items().unwrap().contains("vo.watashi"));
    }

    #[test]
    fn integration_completes_the_lesson() {
        let (repo, store, _) = setup_at("le.l01", 45);

        // L01：45 分方案一天 8 字＋2 文法，隔天整合日。
        complete_all(&repo, &store, monday());
        let got = view(&repo, &store, day(1));
        assert_eq!(keys(&got), vec!["review", "integration:le.l01:1"]);

        done(&repo, &store, day(1), "integration:le.l01:1");

        let progress = repo.lesson_progress().unwrap();
        assert_eq!(progress["le.l01"].completed_date, Some(day(1)));
        assert_eq!(progress["le.l01"].integration_days_done, 1);
        assert_eq!(
            progress["le.l01"].integration_dialogue.as_deref(),
            Some("di.self_intro")
        );
        assert_eq!(
            repo.activity_range(day(1), day(1)).unwrap()[0].lessons_done,
            1
        );
    }

    #[test]
    fn ten_minute_plan_needs_two_integration_days() {
        let (repo, store, _) = setup_at("le.l02", 10);
        seed_lessons_through(&repo, &store, "le.l02", &ctx_on(monday()));

        // L02：10 分方案每天 3 字，2 字＋2 文法 1 天，再 2 天整合。
        complete_all(&repo, &store, monday());
        for card in [
            "vo.taberu:recog",
            "vo.nomu:recog",
            "gr.wo_obj:use",
            "gr.masu:use",
        ] {
            first_contact(&repo, card, ctx_on(monday()).now);
        }
        let got = view(&repo, &store, day(1));
        assert_eq!(new_key_or_integration(&got), "integration:le.l02:1");
        done(&repo, &store, day(1), "integration:le.l02:1");
        assert!(repo.lesson_progress().unwrap()["le.l02"]
            .completed_date
            .is_none());

        let got = view(&repo, &store, day(2));
        assert_eq!(new_key_or_integration(&got), "integration:le.l02:2");
        done(&repo, &store, day(2), "integration:le.l02:2");

        assert_eq!(
            repo.lesson_progress().unwrap()["le.l02"].completed_date,
            Some(day(2))
        );
    }

    fn new_key_or_integration(view: &TodayView) -> String {
        view.tasks
            .iter()
            .find_map(|t| {
                matches!(
                    t.task,
                    DailyTask::NewContent { .. } | DailyTask::Integration { .. }
                )
                .then(|| t.task.key().to_owned())
            })
            .unwrap()
    }

    /// 用 `insert_plan` 的略過寫入造出已完成的 L 課（測試捷徑）。
    fn seed_lessons_through(
        repo: &SqliteRepository,
        store: &ContentStore,
        lesson: &str,
        ctx: &DayContext,
    ) {
        let rows = jp_store::SkipWrite {
            item_intros: store
                .course()
                .order
                .iter()
                .take_while(|id| id.as_str() != lesson)
                .flat_map(|id| {
                    lesson_item_ids(id, store)
                        .into_iter()
                        .map(move |item| (item, id.clone()))
                })
                .map(|(item, id)| jp_store::ItemIntroRow {
                    item_id: item,
                    lesson_id: id,
                    logical_date: ctx.today(),
                    introduced_at: ctx.now,
                })
                .collect(),
            lesson_ids: store
                .course()
                .order
                .iter()
                .take_while(|id| id.as_str() != lesson)
                .cloned()
                .collect(),
            completed_date: ctx.today() - Duration::days(30),
            completed_at: ctx.now,
        };
        let current = repo.active_plan(ctx.today()).unwrap().unwrap();
        let plan = jp_store::NewPlan {
            effective_from: ctx.today(),
            daily_minutes: current.daily_minutes,
            weekday_mask: current.weekday_mask,
            start_level: current.start_level,
            target_date: None,
            created_at: ctx.now,
        };
        repo.insert_plan(&plan, &[], &rows).unwrap();
    }

    #[test]
    fn checkpoint_flow_with_placement_and_dismiss() {
        let (repo, store, _) = setup_at("le.l01", 45);
        // placement 未過的紀錄早於計畫。
        repo.insert_milestone_result(&MilestoneResultRow {
            milestone_id: "ms.hira".to_owned(),
            correct: 5,
            total: 20,
            passed: false,
            logical_date: d("2026-02-01"),
            taken_at: ts("2026-02-01T00:00:00Z"),
        })
        .unwrap();
        // K 課都是 known 略過，不列檢定。
        assert!(!keys(&view(&repo, &store, monday()))
            .iter()
            .any(|k| k.starts_with("checkpoint:")));
    }

    #[test]
    fn placement_failure_then_finishing_k19_lists_the_checkpoint() {
        let (repo, store) = (repo(), content());
        repo.insert_milestone_result(&MilestoneResultRow {
            milestone_id: "ms.hira".to_owned(),
            correct: 5,
            total: 20,
            passed: false,
            logical_date: d("2026-02-01"),
            taken_at: ts("2026-02-01T00:00:00Z"),
        })
        .unwrap();
        // K01–K18 略過，K19 由本人完成。
        let known: Vec<String> = store.course().order.iter().take(18).cloned().collect();
        create_plan(
            &repo,
            &store,
            &ctx_on(monday()),
            &PlanInput {
                known_kana_lessons: known,
                ..input(20)
            },
        );

        let key = new_key(&view(&repo, &store, monday()));
        done(&repo, &store, monday(), &key);

        // 今天的快照已凍結，下一次建立快照才列出。
        let tomorrow = view(&repo, &store, day(1));
        assert!(keys(&tomorrow).contains(&"checkpoint:ms.hira"));

        let dismissed =
            dismiss_checkpoint(&repo, &store, &ctx_on(day(1)), "ms.hira", AUDIO).unwrap();
        assert!(!keys(&dismissed).contains(&"checkpoint:ms.hira"));
        assert!(repo.dismissed_milestones().unwrap().contains("ms.hira"));
    }

    #[test]
    fn dismiss_unknown_milestone_is_not_found() {
        let (repo, store) = setup(20);

        let err =
            dismiss_checkpoint(&repo, &store, &ctx_on(monday()), "ms.nope", AUDIO).unwrap_err();

        assert!(matches!(err, PlanError::NotFound { .. }));
    }

    #[test]
    fn today_slice_done_reflects_the_snapshot() {
        let (repo, store) = setup(20);
        assert!(!today_slice_done(&repo, monday()).unwrap());

        let key = new_key(&view(&repo, &store, monday()));
        assert!(!today_slice_done(&repo, monday()).unwrap());

        done(&repo, &store, monday(), &key);
        assert!(today_slice_done(&repo, monday()).unwrap());
    }

    #[test]
    fn plan_change_same_day_recomputes_snapshot_and_keeps_done_tasks() {
        let (repo, store) = setup(20);
        let first_key = new_key(&view(&repo, &store, monday()));
        done(&repo, &store, monday(), &first_key);

        let bigger = PlanInput {
            weekday_mask: ALL_DAYS_MASK,
            start_level: StartLevel::Zero,
            ..input(45)
        };
        create_plan(&repo, &store, &ctx_on(monday()), &bigger);

        let after = view(&repo, &store, monday());
        assert_eq!(after.budget.kana_chars_limit, 10);
        // 已完成的切片 item_intro 已寫入，新切片不會與舊 key 混淆。
        assert_ne!(new_key(&after), first_key);
    }
}
