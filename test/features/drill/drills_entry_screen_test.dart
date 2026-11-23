import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../grammar/grammar_fixtures.dart';

Finder _rich(String text) => find.textContaining(text, findRichText: true);

String _path(ProviderContainer c) =>
    c.read(appRouterProvider).state.uri.toString();

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  double width = 375,
  double textScale = 1,
  bool settle = true,
}) => pumpApp(
  tester,
  backend: backend,
  location: AppRoutes.drills,
  settings: settingsFixture(),
  width: width,
  height: 1200,
  textScale: textScale,
  settle: settle,
);

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.course.overviewStub.returns(
      overviewFixture(
        currentLessonId: 'le.l02',
        lessons: [
          lessonFixture(
            'le.k01',
            stageId: 'st.s0',
            titleZh: '{ja:あ}行',
            status: LessonStatus.done,
          ),
          lessonFixture('le.l01', status: LessonStatus.done),
          lessonFixture(
            'le.l02',
            titleZh: '這是什麼',
            status: LessonStatus.current,
          ),
          lessonFixture('le.l03', titleZh: '多少錢'),
        ],
      ),
    );
  });

  testWidgets('依階段列出課，未發布的階段不出現', (tester) async {
    await _pump(tester, backend);

    expect(find.text('假名與發音'), findsOneWidget);
    expect(find.text('敬體基礎'), findsOneWidget);
    expect(find.text('參考 N4 口語核心'), findsNothing);
    expect(_rich('第 3 課  多少錢'), findsOneWidget);
    expect(_rich('あ'), findsWidgets);
  });

  testWidgets('目前的課放在最上面', (tester) async {
    await _pump(tester, backend);

    expect(find.text('接著練'), findsOneWidget);
    expect(_rich('第 2 課  這是什麼'), findsNWidgets(2));
    expect(
      tester.getTopLeft(_rich('第 2 課  這是什麼').first).dy,
      lessThan(tester.getTopLeft(find.text('假名與發音')).dy),
    );
  });

  testWidgets('游標走完時沒有「接著練」', (tester) async {
    backend.course.overviewStub.returns(
      overviewFixture(lessons: [lessonFixture('le.l01')]),
    );
    await _pump(tester, backend);

    expect(find.text('接著練'), findsNothing);
  });

  testWidgets('點課進 D2，帶課 ID', (tester) async {
    final container = await _pump(tester, backend);

    await tester.tap(_rich('第 3 課  多少錢'));
    await tester.pumpAndSettle();

    expect(_path(container), '/session/drill?lesson=le.l03');
  });

  testWidgets('沒有課時顯示空狀態', (tester) async {
    backend.course.overviewStub.returns(overviewFixture());
    await _pump(tester, backend);

    expect(find.text('這一版還沒有可以練的課'), findsOneWidget);
  });

  testWidgets('載入時顯示骨架', (tester) async {
    final gate = Completer<void>();
    backend.course.overviewStub.gate = gate.future;
    await _pump(tester, backend, settle: false);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SkeletonLines), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('錯誤可重試', (tester) async {
    backend.course.overviewStub.throws(const StorageFailure());
    await _pump(tester, backend);
    expect(find.byType(ErrorSlip), findsOneWidget);

    backend.course.overviewStub.returns(
      overviewFixture(lessons: [lessonFixture('le.l01')]),
    );
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(_rich('第 1 課'), findsOneWidget);
  });

  testWidgets('320 寬、1.5 倍字級不溢位', (tester) async {
    await _pump(tester, backend, width: 320, textScale: 1.5);
    expect(tester.takeException(), isNull);
  });
}
