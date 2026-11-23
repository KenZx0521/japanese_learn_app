import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/today/today_copy.dart';

import '../../support/fixtures.dart';
import 'today_tasks.dart';

String _detail(TaskDto task, {String? milestoneTitle}) =>
    taskDetail(task, reviewCap: 100, milestoneTitle: milestoneTitle);

void main() {
  group('複習列的張數跟 review_cap 一致（loop.F3）', () {
    test('積壓超過上限時只列今天做的量', () {
      final task = reviewTask(due: 206, learning: 0, minutes: 8.5);

      expect(taskDetail(task, reviewCap: 38), '今天先做 38 張，其餘之後再排 · 8.5 分');
    });

    test('learning 不受上限', () {
      final task = reviewTask(due: 58, learning: 3, minutes: 4.5);

      expect(taskDetail(task, reviewCap: 19), '今天先做 22 張，其餘之後再排 · 4.5 分');
    });

    test('沒超過上限時維持原樣', () {
      final task = reviewTask(due: 16, learning: 2, minutes: 2.5);

      expect(taskDetail(task, reviewCap: 16), '18 張 · 2.5 分');
    });
  });

  group('T1 的複習列（裁決 4）', () {
    test('due 加 learning 為 0 時不列，其餘任務順序不變', () {
      final view = todayFixture(
        tasks: [reviewTask(due: 0, learning: 0, done: true), drillTask()],
      );

      expect(visibleTasks(view).single.key, 'drill');
    });

    test('有卡片時照列', () {
      final view = todayFixture(tasks: [reviewTask(due: 1, learning: 0)]);

      expect(visibleTasks(view), hasLength(1));
    });

    test('只剩收尾新卡時照列（裁決 U5）', () {
      final view = todayFixture(
        tasks: [reviewTask(due: 0, learning: 0, newCards: 3, done: true)],
      );

      expect(visibleTasks(view), hasLength(1));
    });

    test('只剩收尾新卡時副標寫之後要看的張數，不寫「0 張」（裁決 U5）', () {
      final task = reviewTask(
        due: 0,
        learning: 0,
        newCards: 3,
        minutes: 0.5,
        done: true,
      );

      expect(_detail(task), '最後再看 3 張新卡 · 0.5 分');
    });

    test('沒有到期卡但還有學習中的卡時寫張數（review_f F9）', () {
      final task = reviewTask(due: 0, learning: 2, newCards: 3, minutes: 1);

      expect(_detail(task), '2 張 · 1 分');
    });

    test('還有到期卡時張數不含收尾新卡，文案不變', () {
      final task = reviewTask(due: 2, learning: 1, newCards: 3, minutes: 1.5);

      expect(_detail(task), '3 張 · 1.5 分');
    });
  });

  group('T3 學習時間（裁決 5）', () {
    test('不到一分鐘', () {
      expect(studyTimeLabel(0), '不到 1 分鐘');
      expect(studyTimeLabel(0.4), '不到 1 分鐘');
    });

    test('一分鐘以上取整數', () {
      expect(studyTimeLabel(1), '1 分鐘');
      expect(studyTimeLabel(12.5), '13 分鐘');
    });
  });

  group('任務列標題與副標（§3.2）', () {
    test('Review 顯示 due + learning 張', () {
      final task = reviewTask(due: 16, learning: 2, minutes: 2.5);

      expect(taskTitle(task), '複習');
      expect(_detail(task), '18 張 · 2.5 分');
    });

    test('NewContent 只列非 0 的數量', () {
      expect(_detail(newContentTask(kana: 5, minutes: 14)), '5 字 · 14 分');
      expect(
        _detail(
          newContentTask(kana: 0, words: 5, grammar: 1, rules: 2, minutes: 6),
        ),
        '5 字＋1 文法、2 規則 · 6 分',
      );
      expect(taskTitle(newContentTask()), '新內容 あ行');
    });

    test('Integration 的階段', () {
      expect(_detail(integrationTask()), '第 1、2 段 · 4 分');
      expect(
        _detail(integrationTask(phases: const [1, 2, 3, 4])),
        '全部四段 · 4 分',
      );
    });

    test('Checkpoint 帶外部標題', () {
      expect(taskTitle(checkpointTask()), '里程碑檢定');
      expect(_detail(checkpointTask(), milestoneTitle: '平假名'), '平假名');
      expect(_detail(checkpointTask()), '');
    });
  });

  group('標題句', () {
    test('有 NewContent 時用 title_zh 組句', () {
      expect(
        todayHeadline(todayFixture(tasks: [newContentTask(titleZh: 'か行')])),
        '今天，先把か行認熟。',
      );
    });

    test('沒有 NewContent 時固定一句', () {
      expect(todayHeadline(todayFixture(tasks: [reviewTask()])), '今天把學過的再練熟。');
    });
  });

  group('分鐘與日期', () {
    test('estimated_minutes 無條件進位', () {
      expect(estimatedLabel(16.2), '約 17 分鐘');
      expect(estimatedLabel(17), '約 17 分鐘');
    });

    test('分鐘數去掉 .0', () {
      expect(minutesLabel(3), '3');
      expect(minutesLabel(2.5), '2.5');
    });

    test('logical_date 轉月日與星期', () {
      expect(dateLabel('2026-03-02'), '3 月 2 日');
      expect(weekdayLabel('2026-03-02'), '週一');
    });

    test('本週已學天數只算本週一到週日的 is_active', () {
      CalendarDayDto day(String date, {bool active = true}) => CalendarDayDto(
        date: date,
        isStudyDay: true,
        isActive: active,
        lessonIds: const [],
      );

      expect(
        countStudiedThisWeek([
          day('2026-03-01'),
          day('2026-03-02'),
          day('2026-03-03', active: false),
          day('2026-03-04'),
          day('2026-03-09'),
        ], '2026-03-04'),
        2,
      );
    });
  });

  group('recovery 文案（§3.2）', () {
    String message(
      RecoveryReason reason, {
      bool minimal = false,
      bool slice = true,
    }) => recoveryMessage(reason, minimalNew: minimal, hasMainSlice: slice);

    test('不責備的語氣，依 minimal_new 分流', () {
      expect(
        message(RecoveryReason.returnAfterBreak, slice: false),
        '歡迎回來。今天先複習，主線新內容暫停。',
      );
      // RULINGS O11：不給新內容的日子時間全給複習，但檢定照常列出，
      // 所以不說「只複習」（review_fc F3）。
      expect(
        message(RecoveryReason.reviewBacklog, slice: false),
        '複習累積了一些，今天的時間先給複習，主線新內容暫停。',
      );
      expect(
        message(RecoveryReason.reviewBacklog, minimal: true),
        '複習還有一些，今天學一小批新的。',
      );
      expect(
        message(RecoveryReason.unseenNewCards, slice: false),
        '前幾天的新內容還沒看完，今天先看完。',
      );
      expect(
        message(RecoveryReason.unseenNewCards, minimal: true),
        '前幾天的新內容還沒看完，今天先學一小批。',
      );
    });

    // review_fc F3：學完全部課後仍可能是 Minimal，當天卻沒有主線切片。
    test('minimal_new 但沒有主線切片時不說學新的', () {
      expect(
        message(RecoveryReason.reviewBacklog, minimal: true, slice: false),
        '複習還有一些，今天先複習。',
      );
      expect(
        message(RecoveryReason.unseenNewCards, minimal: true, slice: false),
        '前幾天的新內容還沒看完，今天先看完。',
      );
    });

    test('任何原因的文案都不提專區', () {
      for (final minimal in [false, true]) {
        for (final slice in [false, true]) {
          for (final reason in RecoveryReason.values) {
            expect(
              message(reason, minimal: minimal, slice: slice),
              isNot(contains('專區')),
            );
          }
        }
      }
    });
  });
}
