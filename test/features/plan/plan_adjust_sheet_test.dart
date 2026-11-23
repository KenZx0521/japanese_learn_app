import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/plan/plan_screen.dart';
import 'package:japanese_learn_app/features/plan/scope_copy.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';
import 'plan_fixtures.dart';

void main() {
  FakeBackend backendWith({
    PlanViewDto? view,
    PlanViewDto? preview,
    CourseOverviewDto? course,
  }) {
    final backend = FakeBackend();
    final current = view ?? planView();
    backend.plan.viewStub.returns(current);
    backend.plan.previewStub.returns(preview ?? current);
    backend.plan.updateStub.returns(current);
    backend.course.overviewStub.returns(course ?? overview());
    backend.plan.calendarStub.returns(fourWeeks());
    return backend;
  }

  Future<void> openSheet(WidgetTester tester, FakeBackend backend) async {
    await pumpApp(tester, backend: backend, child: const PlanScreen());
    await tester.scrollUntilVisible(find.text('調整計畫'), 200);
    await tester.tap(find.text('調整計畫'));
    await tester.pumpAndSettle();
  }

  PlanInputDto lastPreview(FakeBackend backend) =>
      backend.plan.previewStub.calls.last.single! as PlanInputDto;

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('開啟時顯示說明並以目前設定試算', (tester) async {
    final backend = backendWith();
    await openSheet(tester, backend);
    expect(find.text('只影響之後的安排，不會重置進度'), findsOneWidget);
    expect(lastPreview(backend).dailyMinutes, 20);
    expect(find.text('假名與入門七課約在 3/15 完成（粗估）'), findsWidgets);
  });

  testWidgets('改分鐘重新試算，顯示與現在的差距', (tester) async {
    final backend = backendWith();
    backend.plan.previewStub.answers((args) {
      final input = args.single! as PlanInputDto;
      return planView(
        mainEnd: input.dailyMinutes == 30 ? '2027-03-05' : '2027-03-15',
        input: input,
      );
    });
    await openSheet(tester, backend);

    await tapAndSettle(tester, find.text('30 分'));

    expect(lastPreview(backend).dailyMinutes, 30);
    expect(find.text('假名與入門七課約在 3/5 完成（粗估）'), findsOneWidget);
    expect(find.text('比現在的安排早 10 天'), findsOneWidget);
  });

  testWidgets('p0 的試算寫本版到 L30', (tester) async {
    final backend = backendWith(course: overview(stage: ContentStage.p0));
    await openSheet(tester, backend);
    expect(find.text('本版到 L30，約在 3/15 完成（粗估）'), findsWidgets);
    expect(find.textContaining('專區'), findsNothing);
  });

  testWidgets('取消所有學習日時不試算、不能套用', (tester) async {
    final backend = backendWith(
      view: planView(input: planInput(weekdays: [1])),
    );
    await openSheet(tester, backend);
    final calls = backend.plan.previewStub.calls.length;

    await tapAndSettle(tester, find.bySemanticsLabel(RegExp('週一')));

    expect(backend.plan.previewStub.calls.length, calls);
    expect(find.text('至少要選一天'), findsOneWidget);
    await tapAndSettle(tester, find.text('套用'));
    expect(backend.plan.updateStub.calls, isEmpty);
  });

  testWidgets('沒有變更時不能套用', (tester) async {
    final backend = backendWith();
    await openSheet(tester, backend);
    await tapAndSettle(tester, find.text('套用'));
    expect(backend.plan.updateStub.calls, isEmpty);
    expect(find.text('只影響之後的安排，不會重置進度'), findsOneWidget);
  });

  testWidgets('套用寫入、關閉面板並重新整理', (tester) async {
    final backend = backendWith();
    await openSheet(tester, backend);
    final viewCalls = backend.plan.viewStub.calls.length;

    await tapAndSettle(tester, find.text('45 分'));
    await tapAndSettle(tester, find.text('套用'));

    final sent = backend.plan.updateStub.calls.single.single! as PlanInputDto;
    expect(sent.dailyMinutes, 45);
    expect(sent.knownKanaLessons, ['le.k01']);
    expect(find.text('只影響之後的安排，不會重置進度'), findsNothing);
    expect(backend.plan.viewStub.calls.length, greaterThan(viewCalls));
  });

  testWidgets('套用失敗時留在面板並顯示訊息', (tester) async {
    final backend = backendWith();
    backend.plan.updateStub.throws(const StorageFailure());
    await openSheet(tester, backend);
    await tapAndSettle(tester, find.text('10 分'));
    await tapAndSettle(tester, find.text('套用'));
    expect(find.textContaining('資料暫時寫不進去'), findsOneWidget);
    expect(find.text('只影響之後的安排，不會重置進度'), findsOneWidget);
  });

  testWidgets('試算失敗顯示 ErrorSlip，重試成功', (tester) async {
    final backend = backendWith();
    backend.plan.previewStub.throws(const InvalidInputFailure());
    await openSheet(tester, backend);
    expect(find.textContaining('這個操作現在無法完成'), findsOneWidget);

    backend.plan.previewStub.returns(planView());
    await tapAndSettle(tester, find.text('重試'));
    expect(find.textContaining('這個操作現在無法完成'), findsNothing);
  });

  testWidgets('目標日期可設定、調整與清除', (tester) async {
    final backend = backendWith();
    await openSheet(tester, backend);

    await tapAndSettle(tester, find.text('設定日期'));
    final firstDate = lastPreview(backend).targetDate;
    expect(firstDate, isNotNull);

    await tapAndSettle(tester, find.bySemanticsLabel('月，加一'));
    final bumped = lastPreview(backend).targetDate;
    expect(bumped, isNot(firstDate));

    await tapAndSettle(tester, find.text('不設定'));
    expect(lastPreview(backend).targetDate, isNull);
  });

  testWidgets('日期不能選到今天以前', (tester) async {
    final backend = backendWith(
      view: planView(input: planInput(targetDate: '2020-01-01')),
    );
    await openSheet(tester, backend);
    await tapAndSettle(tester, find.bySemanticsLabel('年，減一'));
    // 比邏輯日而不是現在時刻：00:00–04:00 邏輯日還是昨天（fixture 換日 4 點）
    final logicalToday = DateTime.parse(logicalDateOf(DateTime.now(), 4));
    expect(
      DateTime.parse(lastPreview(backend).targetDate!).isAfter(logicalToday),
      isTrue,
    );
  });

  testWidgets('試算趕不上時可套用建議分鐘到草稿', (tester) async {
    final backend = backendWith(
      preview: planView(status: PlanStatus.behind, suggested: 45),
    );
    await openSheet(tester, backend);
    expect(find.textContaining('趕不上目標日期'), findsOneWidget);

    await tapAndSettle(tester, find.text('改成每天 45 分鐘'));
    expect(lastPreview(backend).dailyMinutes, 45);
  });

  testWidgets('字級 1.5 倍、寬 320 不溢位', (tester) async {
    final backend = backendWith();
    await pumpApp(
      tester,
      backend: backend,
      child: const PlanScreen(),
      width: 320,
      height: 800,
      textScale: 1.5,
    );
    await tester.scrollUntilVisible(find.text('調整計畫'), 200);
    await tester.tap(find.text('調整計畫'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('設定日期'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('學習日選項至少 48dp', (tester) async {
    await openSheet(tester, backendWith());
    final size = tester.getSize(find.bySemanticsLabel(RegExp('週一')).first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.byType(Material), findsWidgets);
  });
}
