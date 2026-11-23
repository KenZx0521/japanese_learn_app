import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/kana_cell.dart';
import 'package:japanese_learn_app/design/widgets/speak_button.dart';
import 'package:japanese_learn_app/features/kana/kana_chart_screen.dart';
import 'package:japanese_learn_app/features/kana/kana_session_screen.dart';
import 'package:japanese_learn_app/features/kana/rule_card_screen.dart';
import 'package:japanese_learn_app/features/listening/sounds_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'kana_fixtures.dart';

final _detailA = detailOf(kanaCellFixture());

Future<void> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  FakeTtsEngine? tts,
  double width = 375,
  double height = 800,
  double textScale = 1,
  bool settle = true,
  SettingsDto? settings,
}) => pumpApp(
  tester,
  backend: backend,
  tts: tts,
  width: width,
  height: height,
  textScale: textScale,
  settle: settle,
  settings: settings ?? settingsFixture(),
  child: const KanaChartScreen(),
);

/// 走完整路由，測跳轉與回來後的重新整理。
Future<void> _pumpRoute(WidgetTester tester, FakeBackend backend) => pumpApp(
  tester,
  backend: backend,
  location: AppRoutes.kana,
  settings: seenHints(),
);

Finder _cell(String kana) => find.widgetWithText(KanaCell, kana);

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    stubCharts(backend);
    stubDetails(backend, [_detailA]);
  });

  testWidgets('顯示分區、格子與 romaji，不呼叫 display_policy', (tester) async {
    await _pump(tester, backend);

    expect(find.text('清音'), findsOneWidget);
    expect(find.text('拗音'), findsOneWidget);
    expect(_cell('あ'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('yu'), findsOneWidget);
    expect(backend.settings.displayPolicyStub.calls, isEmpty);
  });

  testWidgets('切換片假名時改取片假名表', (tester) async {
    await _pump(tester, backend);

    await tester.tap(find.text('片假名'));
    await tester.pumpAndSettle();

    expect(_cell('ア'), findsOneWidget);
    expect(_cell('あ'), findsNothing);
  });

  testWidgets('點格子會發音並顯示字源、記憶法與例字', (tester) async {
    final tts = FakeTtsEngine();
    await _pump(tester, backend, tts: tts);

    await tester.tap(_cell('あ'));
    await tester.pumpAndSettle();

    expect(tts.spoken.single.id, 'ka.hira.a');
    expect(backend.kana.detailStub.calls.single, ['ka.hira.a']);
    expect(find.textContaining('來自漢字'), findsOneWidget);
    expect(find.text('安'), findsOneWidget);
    expect(find.textContaining('嘴巴自然張開', findRichText: true), findsOneWidget);
    expect(find.text('あい'), findsOneWidget);
    expect(find.text('例字中文'), findsOneWidget);
    expect(find.text('1 倍'), findsOneWidget);
    expect(find.byType(SpeakButton), findsNWidgets(2));
  });

  testWidgets('連續點不同格子可以連續聽', (tester) async {
    final tts = FakeTtsEngine();
    stubDetails(backend, [
      _detailA,
      detailOf(kanaCellFixture(id: 'ka.hira.i', ch: 'い', romaji: 'i')),
    ]);
    await _pump(tester, backend, tts: tts);

    await tester.tap(_cell('あ'));
    await tester.pumpAndSettle();
    await tester.tap(_cell('い'));
    await tester.pumpAndSettle();

    expect(tts.spoken.map((r) => r.id), ['ka.hira.a', 'ka.hira.i']);
    expect(find.textContaining('來自漢字'), findsOneWidget);
  });

  testWidgets('listen_disabled 的字不播音，改顯示看例字', (tester) async {
    final tts = FakeTtsEngine();
    stubCharts(backend, hira: hiraganaChart(listenDisabled: true));
    stubDetails(backend, [
      detailOf(kanaCellFixture(listenDisabled: true), origin: null),
    ]);
    await _pump(tester, backend, tts: tts);

    await tester.tap(_cell('あ'));
    await tester.pumpAndSettle();

    expect(tts.spoken, isEmpty);
    expect(find.text('單獨唸不準，看例字'), findsOneWidget);
    expect(find.textContaining('來自漢字'), findsNothing);
  });

  testWidgets('語音不可用時顯示橫幅、斜線喇叭，點格子不播音也不報錯', (tester) async {
    final tts = FakeTtsEngine(
      availability: const TtsAvailability(TtsAvailabilityKind.engineMissing),
    );
    await _pump(tester, backend, tts: tts);

    expect(find.text('語音無法使用，聽力題暫時不出現'), findsOneWidget);
    await tester.tap(_cell('あ'));
    await tester.pumpAndSettle();

    expect(tts.spoken, isEmpty);
    expect(find.bySemanticsLabel('語音無法使用，查看說明'), findsWidgets);
  });

  testWidgets('易混字組並排顯示，點成員切換到該字', (tester) async {
    final nu = kanaCellFixture(id: 'ka.hira.nu', ch: 'ぬ', romaji: 'nu');
    final me = kanaCellFixture(id: 'ka.hira.me', ch: 'め', romaji: 'me');
    final group = ConfusableDto(
      id: 'ka.cf.nu_me',
      kind: ConfusableKindDto.shape,
      members: [nu, me],
      literals: const [],
      diffZh: '{ja:ぬ} 收筆有圈',
    );
    stubDetails(backend, [
      detailOf(nu, confusables: [group], hint: '提示一'),
      detailOf(me, confusables: [group], hint: '提示二'),
      _detailA,
    ]);
    stubCharts(
      backend,
      hira: [
        KanaGroupDto(
          titleZh: '清音',
          columns: 2,
          rows: [
            rowOf([nu, me]),
          ],
        ),
      ],
    );
    final tts = FakeTtsEngine();
    await _pump(tester, backend, tts: tts, height: 1000);

    await tester.tap(_cell('ぬ').first);
    await tester.pumpAndSettle();
    expect(find.text('容易混淆'), findsOneWidget);
    expect(find.textContaining('收筆有圈', findRichText: true), findsOneWidget);

    await tester.tap(_cell('め').last);
    await tester.pumpAndSettle();
    expect(backend.kana.detailStub.calls.last, ['ka.hira.me']);
    expect(find.textContaining('提示二', findRichText: true), findsOneWidget);
    expect(tts.spoken.last.id, 'ka.hira.me');
  });

  testWidgets('規則卡連結與練習按鈕帶正確路徑', (tester) async {
    stubDetails(backend, [
      detailOf(kanaCellFixture(), lessonId: 'le.k01', ruleId: 'ka.rule.a'),
    ]);
    backend.kana.ruleCardStub.returns(ruleCardFixture());
    backend.kana.sessionStub.returns(const []);
    backend.course.lessonStub.returns(lessonOf(const []));
    await _pumpRoute(tester, backend);

    await tester.tap(_cell('あ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('看規則卡'));
    await tester.pumpAndSettle();
    expect(find.byType(RuleCardScreen), findsOneWidget);
    expect(backend.kana.ruleCardStub.calls.single, ['ka.rule.a']);

    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('練習這一課'));
    await tester.pumpAndSettle();
    expect(find.byType(KanaSessionScreen), findsOneWidget);
    expect(backend.course.lessonStub.calls.single, ['le.k01']);
  });

  testWidgets('進度全空時提供第一課按鈕；有進度時不顯示', (tester) async {
    backend.kana.sessionStub.returns(const []);
    backend.course.lessonStub.returns(lessonOf(const []));
    await _pumpRoute(tester, backend);

    expect(find.text('從第一課開始'), findsOneWidget);
    await tester.tap(find.text('從第一課開始'));
    await tester.pumpAndSettle();
    expect(find.byType(KanaSessionScreen), findsOneWidget);
    expect(backend.course.lessonStub.calls.single, ['le.k01']);
  });

  testWidgets('片假名的第一課是 le.kk01', (tester) async {
    backend.kana.sessionStub.returns(const []);
    backend.course.lessonStub.returns(lessonOf(const [], id: 'le.kk01'));
    await _pumpRoute(tester, backend);

    await tester.tap(find.text('片假名'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('從第一課開始'));
    await tester.pumpAndSettle();
    expect(backend.course.lessonStub.calls.single, ['le.kk01']);
  });

  testWidgets('已有進度時不顯示第一課按鈕', (tester) async {
    stubCharts(backend, hira: hiraganaChart(status: KanaStatus.learning));
    await _pump(tester, backend);
    expect(find.text('從第一課開始'), findsNothing);
  });

  testWidgets('載入中先畫靜態表，進度回來後換成真實狀態', (tester) async {
    final gate = Completer<void>();
    backend.kana.chartStub.gate = gate.future;
    await _pump(tester, backend, settle: false);
    await tester.pump();

    expect(_cell('か'), findsOneWidget);
    expect(find.text('從第一課開始'), findsNothing);

    stubCharts(backend, hira: hiraganaChart(status: KanaStatus.mastered));
    gate.complete();
    await tester.pumpAndSettle();

    expect(_cell('か'), findsNothing);
    final cell = tester.widget<KanaCell>(_cell('あ'));
    expect(cell.status, KanaStatus.mastered);
  });

  testWidgets('進度讀取失敗仍顯示表，標示並可重試', (tester) async {
    backend.kana.chartStub.throws(const StorageFailure());
    await _pump(tester, backend);

    expect(_cell('か'), findsOneWidget);
    expect(find.text('進度暫時讀不到'), findsOneWidget);
    expect(find.text('從第一課開始'), findsNothing);

    stubCharts(backend);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('進度暫時讀不到'), findsNothing);
    expect(_cell('か'), findsNothing);
  });

  testWidgets('詳情讀取失敗顯示 ErrorSlip，重試後恢復', (tester) async {
    backend.kana.detailStub.throws(const ContentFailure());
    await _pump(tester, backend);

    await tester.tap(_cell('あ'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorSlip), findsOneWidget);

    stubDetails(backend, [_detailA]);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorSlip), findsNothing);
    expect(find.textContaining('來自漢字'), findsOneWidget);
  });

  testWidgets('從練習回來會重新讀取進度', (tester) async {
    backend.kana.sessionStub.returns(const []);
    backend.course.lessonStub.returns(lessonOf(const []));
    await _pumpRoute(tester, backend);
    final before = backend.kana.chartStub.calls.length;

    await tester.tap(_cell('あ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('練習這一課'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回上一頁'));
    await tester.pumpAndSettle();

    expect(find.byType(KanaChartScreen), findsOneWidget);
    expect(backend.kana.chartStub.calls.length, greaterThan(before));
  });

  testWidgets('語音示範連到聽說的語音示範頁', (tester) async {
    await _pumpRoute(tester, backend);

    await tester.ensureVisible(find.text('語音示範'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('語音示範'));
    await tester.pumpAndSettle();

    expect(find.byType(SoundsScreen), findsOneWidget);
  });

  testWidgets('互動目標達 48dp 且都有語意', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, backend, width: 320);
    await tester.tap(_cell('あ'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('寬螢幕詳情在右欄', (tester) async {
    await _pump(tester, backend, width: 1200, height: 900);

    await tester.tap(_cell('あ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('來自漢字'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 寬、字級 1.5 倍不破版', (tester) async {
    await _pump(tester, backend, width: 320, height: 640, textScale: 1.5);

    await tester.tap(_cell('あ'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
