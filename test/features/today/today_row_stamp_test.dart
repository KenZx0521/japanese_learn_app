// §4.1：朱色稀缺。列上的小章用淡墨，朱色留給導覽與今日章。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/features/today/today_screen.dart';
import 'package:japanese_learn_app/features/today/today_task_list.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'today_tasks.dart';

void main() {
  testWidgets('沒有卡片的複習列不顯示，序號從下一項算起', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(
      todayFixture(
        tasks: [reviewTask(due: 0, learning: 0, done: true), drillTask()],
      ),
    );
    await pumpApp(tester, backend: backend, child: const TodayScreen());

    expect(find.text('複習'), findsNothing);
    expect(find.text('句型演練'), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(find.text('開始'), findsOneWidget);
  });

  testWidgets('休息日只有空的複習列時走空狀態，不蓋完成章', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(
      todayFixture(
        tasks: [reviewTask(due: 0, learning: 0, done: true)],
        isStudyDay: false,
      ),
    );
    await pumpApp(tester, backend: backend, child: const TodayScreen());

    expect(find.text('複習'), findsNothing);
    expect(find.byType(HankoBadge), findsNothing);
    expect(find.textContaining('今天沒有排定的任務'), findsOneWidget);
  });

  testWidgets('只剩收尾新卡時列出複習列，不寫「0 張」（裁決 U5）', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(
      todayFixture(
        tasks: [
          reviewTask(
            due: 0,
            learning: 0,
            newCards: 3,
            minutes: 0.5,
            done: true,
          ),
          drillTask(),
        ],
        learningTail: 3,
      ),
    );
    await pumpApp(tester, backend: backend, child: const TodayScreen());

    expect(find.text('複習'), findsOneWidget);
    expect(find.text('最後再看 3 張新卡 · 0.5 分'), findsOneWidget);
    expect(find.textContaining('0 張'), findsNothing);
    expect(find.text('二'), findsOneWidget);
  });

  testWidgets('只剩收尾新卡時不蓋完成章：今天還沒碰過這些卡（review_f F2）', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(
      todayFixture(
        tasks: [
          reviewTask(
            due: 0,
            learning: 0,
            newCards: 3,
            minutes: 0.5,
            done: true,
          ),
          drillTask(),
        ],
        learningTail: 3,
      ),
    );
    await pumpApp(tester, backend: backend, child: const TodayScreen());

    expect(find.byType(HankoBadge), findsNothing);
  });

  testWidgets('複習做完、沒有收尾新卡以外的項目時，別的已完成列照樣蓋章', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(
      todayFixture(
        tasks: [
          reviewTask(due: 2, learning: 0, newCards: 3, done: true),
          drillTask(),
        ],
      ),
    );
    await pumpApp(tester, backend: backend, child: const TodayScreen());

    expect(find.byType(HankoBadge), findsOneWidget);
  });

  testWidgets('受限日只有收尾新卡時列出收尾，不走空狀態（裁決 U5）', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(
      todayFixture(
        tasks: [
          reviewTask(
            due: 0,
            learning: 0,
            newCards: 3,
            minutes: 0.5,
            done: true,
          ),
        ],
        learningTail: 3,
      ),
    );
    await pumpApp(tester, backend: backend, child: const TodayScreen());

    expect(find.text('收尾'), findsOneWidget);
    expect(find.text('3 張'), findsOneWidget);
    expect(find.textContaining('今天沒有排定的任務'), findsNothing);
  });

  testWidgets('積壓超過上限時列出今天的量', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(
      todayFixture(
        tasks: [reviewTask(due: 206, learning: 0, minutes: 8.5)],
        reviewCap: 38,
      ),
    );
    await pumpApp(tester, backend: backend, child: const TodayScreen());

    expect(find.textContaining('今天先做 38 張'), findsOneWidget);
    expect(find.textContaining('206'), findsNothing);
  });

  testWidgets('全部完成時不顯示「約 0 分鐘」', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(
      todayFixture(tasks: [reviewTask(done: true)], estimatedMinutes: 0),
    );
    await pumpApp(tester, backend: backend, child: const TodayScreen());

    expect(find.textContaining('約 0'), findsNothing);
  });

  testWidgets('已完成列的小章是 muted', (tester) async {
    await pumpApp(
      tester,
      backend: FakeBackend(),
      child: SingleChildScrollView(
        child: TodayTaskList(
          view: todayFixture(tasks: [reviewTask(done: true), newContentTask()]),
        ),
      ),
    );

    final badge = tester.widget<HankoBadge>(find.byType(HankoBadge));
    expect(badge.muted, isTrue);
  });
}
