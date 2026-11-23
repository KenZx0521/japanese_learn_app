// SA-12：K2、S4 的 Esc；SA-13：設定變動後的相依資料；SA-03、SA-11 的語音收尾。
import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/core/tts/fake_tts_engine.dart';
import 'package:japanese_learn_app/core/tts/tts_controller.dart';
import 'package:japanese_learn_app/core/tts/tts_engine.dart';
import 'package:japanese_learn_app/design/widgets/paper_scaffold.dart';
import 'package:japanese_learn_app/features/dialogue/dialogue.dart';
import 'package:japanese_learn_app/features/dialogue/dialogues_screen.dart';
import 'package:japanese_learn_app/features/kana/kana_chart_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_backend.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';
import 'dialogue/dialogue_fixtures.dart';
import 'learn/learn_fixtures.dart';
import 'today/today_flow_harness.dart';
import 'today/today_tasks.dart';

Future<void> _pumpFrames(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _hideThenShow(WidgetTester tester) {
  final binding = tester.binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  group('Esc 離開（SA-12）', () {
    testWidgets('K2 按 Esc 回假名表', (tester) async {
      final backend = FakeBackend();
      backend.kana.sessionStub.returns(const []);
      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.kanaSession('le.k01'),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(KanaChartScreen), findsOneWidget);
    });

    testWidgets('S4 按 Esc 回對話列表', (tester) async {
      final backend = FakeBackend();
      backend.listening.dialogueStub.returns(dialogueFixture());
      await pumpApp(
        tester,
        backend: backend,
        tts: FakeTtsEngine(autoComplete: false),
        location: AppRoutes.sessionDialogue('di.l01'),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(DialoguesScreen), findsOneWidget);
    });
  });

  group('設定改變後的相依資料（SA-13）', () {
    testWidgets('改羅馬字規則：掛著的課程頁重取 display_policy', (tester) async {
      final backend = FakeBackend();
      backend.course.lessonStub.answers((_) => lessonDetail());
      final container = await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.lesson('le.l01'),
      );
      final before = backend.settings.displayPolicyStub.calls.length;

      await container
          .read(settingsProvider.notifier)
          .patch(settingsPatch(romajiOverride: RomajiMode.hidden));
      await tester.pumpAndSettle();

      expect(
        backend.settings.displayPolicyStub.calls.length,
        greaterThan(before),
      );
    });

    testWidgets('改換日時間：T1 重取今日', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      final container = await pumpApp(tester, backend: backend);
      final before = backend.today.todayStub.calls.length;

      await container
          .read(settingsProvider.notifier)
          .patch(settingsPatch(dayRolloverHour: 0));
      await tester.pumpAndSettle();

      expect(backend.today.todayStub.calls.length, greaterThan(before));
    });

    testWidgets('改語速不重取今日', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      final container = await pumpApp(tester, backend: backend);
      final before = backend.today.todayStub.calls.length;

      await container
          .read(settingsProvider.notifier)
          .patch(settingsPatch(ttsRate: 0.8));
      await tester.pumpAndSettle();

      expect(backend.today.todayStub.calls.length, before);
    });
  });

  group('O5 修好語音後可重新測試（SA-03）', () {
    testWidgets('播放失敗、設定完成回來，回到試聽並重播', (tester) async {
      final backend = FakeBackend();
      final tts = FakeTtsEngine()..speakError = Exception('engine failed');
      await pumpApp(
        tester,
        backend: backend,
        tts: tts,
        onboarded: false,
        location: AppRoutes.welcomeStep('o5'),
        settings: settingsFixture(autoplay: true),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('現在聽不到日語語音。'), findsOneWidget);
      final spokenBefore = tts.spoken.length;

      tts.speakError = null;
      await tapText(tester, '現在設定');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('現在聽不到日語語音。'), findsNothing);
      expect(find.text('聽得到'), findsOneWidget);
      expect(tts.spoken.length, greaterThan(spokenBefore));
    });
  });

  group('角色扮演被打斷（SA-11）', () {
    Future<FakeTtsEngine> startRolePlay(WidgetTester tester) async {
      final tts = FakeTtsEngine(autoComplete: false);
      await pumpApp(
        tester,
        backend: FakeBackend(),
        tts: tts,
        settle: false,
        settings: settingsFixture(autoplay: true),
        child: PaperScaffold(
          scrollable: false,
          body: DialogueRunner(
            dialogue: flowDialogue(),
            phases: const [4],
            onFinished: () {},
          ),
        ),
      );
      await _pumpFrames(tester);
      await tester.tap(find.textContaining('老師').first);
      await _pumpFrames(tester);
      return tts;
    }

    testWidgets('進背景的 stop 不算播完，回前景補播當句', (tester) async {
      final tts = await startRolePlay(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DialogueRunner)),
      );
      expect(find.text('先聽對方說。'), findsOneWidget);
      final spokenBefore = tts.spoken.length;

      await container.read(ttsControllerProvider.notifier).stop();
      await _pumpFrames(tester);

      expect(find.text('第 1／2 句'), findsOneWidget);
      expect(find.text('先聽對方說。'), findsOneWidget);

      _hideThenShow(tester);
      await _pumpFrames(tester);

      expect(tts.spoken.length, greaterThan(spokenBefore));
      expect(find.text('第 1／2 句'), findsOneWidget);
    });

    testWidgets('播完才換下一句', (tester) async {
      final tts = await startRolePlay(tester);

      tts.emit(TtsCompleted(tts.spoken.last.id));
      await _pumpFrames(tester);

      expect(find.text('第 2／2 句'), findsOneWidget);
    });

    testWidgets('按下一句只前進一句', (tester) async {
      await startRolePlay(tester);

      await tester.tap(find.text('下一句'));
      await _pumpFrames(tester);

      expect(find.text('第 2／2 句'), findsOneWidget);
    });
  });

  group('O6 防連點（裁決 8）', () {
    testWidgets('連點「知道了，繼續」只離開一次', (tester) async {
      final backend = FakeBackend();
      backend.firstRunMarker.flag = true;
      final container = await pumpApp(tester, backend: backend);
      final router = container.read(appRouterProvider);
      unawaited(router.push(AppRoutes.planAbout));
      await tester.pumpAndSettle();
      unawaited(router.push(AppRoutes.sessionExpectation));
      await tester.pumpAndSettle();
      final button = find.text('知道了，繼續');
      final gate = Completer<void>();
      backend.firstRunMarker.deleteGate = gate.future;

      await tester.tap(button);
      await tester.pump();
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(backend.firstRunMarker.flag, isFalse);
      expect(find.text('先說清楚能到哪裡'), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.planAbout);
    });

    // review_f F5：離開途中按「關於程度」，之後的 pop 會作用在錯的頁面。
    testWidgets('離開途中「關於程度」不能按', (tester) async {
      final backend = FakeBackend();
      backend.firstRunMarker.flag = true;
      final container = await pumpApp(tester, backend: backend);
      final router = container.read(appRouterProvider);
      unawaited(router.push(AppRoutes.sessionExpectation));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      backend.firstRunMarker.deleteGate = gate.future;

      await tester.tap(find.text('知道了，繼續'));
      await tester.pump();
      await tester.tap(find.text('關於程度'), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('先說清楚能到哪裡'), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.today);
    });
  });
}
