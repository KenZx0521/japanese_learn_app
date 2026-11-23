import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:japanese_learn_app/design/widgets/beat_strip.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/sound_pair_view.dart';
import 'package:japanese_learn_app/features/kana/rule_card_screen.dart';
import 'package:japanese_learn_app/features/session/drill/drill_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

const _ruleId = 'ka.rule.sokuon';

SoundGroupDto _accentGroup() => SoundGroupDto(
  id: 'ka.sg.accent',
  lessonId: 'le.k19',
  kind: SoundGroupKindDto.accent,
  titleZh: '音調對比',
  bodyZh: '高低不同，意思不同。',
  pairs: [
    SoundPairDto(
      a: const SoundSideDto(
        text: 'はし',
        zh: '筷子',
        speech: SpeechDto(text: 'はし', kana: 'はし'),
      ),
      b: const SoundSideDto(
        text: 'はし',
        zh: '橋',
        speech: SpeechDto(text: 'はし', kana: 'はし'),
      ),
      listenDisabled: false,
    ),
  ],
  testDrillIds: const [],
);

RuleCardDto _cardWith({
  List<String> drills = const [],
  List<SoundGroupDto> groups = const [],
}) {
  final base = ruleCardFixture();
  return RuleCardDto(
    id: base.id,
    lessonId: base.lessonId,
    titleZh: base.titleZh,
    bodyZh: base.bodyZh,
    examples: base.examples,
    soundGroups: groups,
    drillIds: drills,
  );
}

Future<void> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  FakeTtsEngine? tts,
  bool settle = true,
  bool disableAnimations = false,
}) => pumpApp(
  tester,
  backend: backend,
  tts: tts,
  settle: settle,
  disableAnimations: disableAnimations,
  settings: settingsFixture(),
  child: const RuleCardScreen(ruleId: _ruleId),
);

Iterable<Element> _litBeats(WidgetTester tester) => find
    .byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color ==
              AppTokens.light.ai.withValues(alpha: 0.22),
    )
    .evaluate();

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend());

  testWidgets('顯示標題、說明、例字與拍感格', (tester) async {
    backend.kana.ruleCardStub.returns(_cardWith());
    await _pump(tester, backend);

    expect(find.textContaining('促音', findRichText: true), findsOneWidget);
    expect(find.text('かっこ'), findsOneWidget);
    expect(find.byType(BeatStrip), findsOneWidget);
    expect(find.bySemanticsLabel('第 2 拍，停一拍'), findsOneWidget);
  });

  testWidgets('播放時整詞送 TTS，收到開始事件後第一拍亮格', (tester) async {
    final tts = FakeTtsEngine(autoComplete: false);
    backend.kana.ruleCardStub.returns(_cardWith());
    await _pump(tester, backend, tts: tts);

    await tester.tap(find.bySemanticsLabel('播放').first);
    await tester.pump();

    expect(tts.spoken.single.text, 'かっこ');
    expect(_litBeats(tester), hasLength(1));
    await tester.pump(const Duration(milliseconds: 320));
    expect(_litBeats(tester), hasLength(1));
    // 走完所有拍，計時器清掉，避免測試結束時還有 Timer
    await tester.pump(const Duration(milliseconds: 640));
    expect(_litBeats(tester), isEmpty);
  });

  testWidgets('無聲模式標示無聲示範，可手動看節拍', (tester) async {
    backend.kana.ruleCardStub.returns(_cardWith());
    await pumpApp(
      tester,
      backend: backend,
      settings: settingsFixture(silentMode: true),
      child: const RuleCardScreen(ruleId: _ruleId),
    );

    expect(find.text('無聲示範'), findsOneWidget);
    await tester.tap(find.text('看節拍'));
    await tester.pump();
  });

  testWidgets('語音示範組顯示 A/B，音調組標註僅供參考', (tester) async {
    backend.kana.ruleCardStub.returns(_cardWith(groups: [_accentGroup()]));
    await _pump(tester, backend);

    expect(find.byType(SoundPairView), findsOneWidget);
    expect(find.text('由裝置合成，僅供參考'), findsOneWidget);
    expect(find.text('筷子'), findsOneWidget);
  });

  testWidgets('有 drill_ids 才顯示測試一下，並帶正確路徑', (tester) async {
    backend.kana.ruleCardStub.returns(_cardWith(drills: ['dr.a', 'dr.b']));
    backend.drills.sessionStub.returns(const []);
    await pumpApp(
      tester,
      backend: backend,
      location: AppRoutes.kanaRule(_ruleId),
      settings: settingsFixture(),
    );

    await tester.tap(find.text('測試一下'));
    await tester.pumpAndSettle();

    final screen = tester.widget<DrillScreen>(find.byType(DrillScreen));
    expect(screen.drills, ['dr.a', 'dr.b']);
  });

  testWidgets('沒有 drill_ids 時不顯示測試一下', (tester) async {
    backend.kana.ruleCardStub.returns(_cardWith());
    await _pump(tester, backend);
    expect(find.text('測試一下'), findsNothing);
  });

  testWidgets('載入中顯示骨架', (tester) async {
    backend.kana.ruleCardStub
      ..gate = Completer<void>().future
      ..returns(_cardWith());
    await _pump(tester, backend, settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('載入中'), findsOneWidget);
  });

  testWidgets('載入失敗顯示 ErrorSlip，重試後恢復', (tester) async {
    backend.kana.ruleCardStub.throws(const NotFoundFailure());
    await _pump(tester, backend);

    expect(find.byType(ErrorSlip), findsOneWidget);

    backend.kana.ruleCardStub.returns(_cardWith());
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorSlip), findsNothing);
    expect(find.byType(BeatStrip), findsOneWidget);
  });

  testWidgets('320 寬、字級 1.5 倍不破版', (tester) async {
    backend.kana.ruleCardStub.returns(_cardWith(groups: [_accentGroup()]));
    await pumpApp(
      tester,
      backend: backend,
      settings: settingsFixture(),
      width: 320,
      height: 640,
      textScale: 1.5,
      child: const RuleCardScreen(ruleId: _ruleId),
    );
    expect(tester.takeException(), isNull);
  });
}
