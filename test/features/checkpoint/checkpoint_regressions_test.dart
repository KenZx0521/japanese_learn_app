// D3 作答中的外部變動：回前景重取今日、語音可用性改變，都不能無聲丟掉進度。
import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/design/widgets/choice_tile.dart';
import 'package:japanese_learn_app/features/checkpoint/checkpoint_flow.dart';
import 'package:japanese_learn_app/features/plan/plan_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../quiz/quiz_fixtures.dart';
import '../today/today_flow_harness.dart';
import '../today/today_tasks.dart';

String? _progress() {
  for (final element in find.byType(Semantics).evaluate()) {
    final label = (element.widget as Semantics).properties.label;
    if (label != null && label.startsWith('第 ') && label.contains('題')) {
      return label;
    }
  }
  return null;
}

QuestionDto _listenQuestion() => choiceQuestion(
  type: QuestionType.listenMeaning,
  prompt: promptFixture(
    text: sentenceFixture(),
    speech: const SpeechDto(text: '猫', kana: 'ねこ'),
    hide: true,
  ),
);

Future<void> _answer(WidgetTester tester) async {
  await tester.tap(find.byType(ChoiceTile).first);
  await tester.pumpAndSettle();
}

void main() {
  group('P1 手動進入（SA-01）', () {
    testWidgets('回前景重取今日時，作答進度不變', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture());
      backend.drills.checkpointStartStub.returns([
        choiceQuestion(),
        choiceQuestion(),
      ]);
      final container = await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionCheckpoint('ms.hira'),
      );
      await tapText(tester, '開始');
      await _answer(tester);
      expect(_progress(), '第 2 題，共 2 題');

      final gate = Completer<void>();
      backend.today.todayStub.gate = gate.future;
      container.read(resumeTickProvider.notifier).bump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CheckpointFlow), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('中途不顯示對錯'), findsNothing);
      expect(_progress(), '第 2 題，共 2 題');
    });
  });

  group('語音可用性改變（SA-08）', () {
    Future<FakeBackend> arrange(List<QuestionDto> questions) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [checkpointTask()]));
      backend.drills.checkpointStartStub.returns(questions);
      return backend;
    }

    testWidgets('題目都不必聽：改無聲後繼續作答', (tester) async {
      final backend = await arrange([
        choiceQuestion(),
        choiceQuestion(),
        choiceQuestion(),
      ]);
      final container = await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
      );
      await tapText(tester, '開始');
      await _answer(tester);
      await _answer(tester);
      expect(_progress(), '第 3 題，共 3 題');

      await container
          .read(settingsProvider.notifier)
          .patch(settingsPatch(silentMode: true));
      await tester.pumpAndSettle();

      expect(_progress(), '第 3 題，共 3 題');
      expect(find.text('中途不顯示對錯'), findsNothing);
    });

    testWidgets('還有要聽的題目：改無聲時明確告知並重新開始', (tester) async {
      final backend = await arrange([choiceQuestion(), _listenQuestion()]);
      final container = await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
      );
      await tapText(tester, '開始');
      await _answer(tester);

      backend.drills.checkpointStartStub.returns([choiceQuestion()]);
      await container
          .read(settingsProvider.notifier)
          .patch(settingsPatch(silentMode: true));
      await tester.pumpAndSettle();

      expect(find.text('語音改變了，檢定要重新開始。'), findsOneWidget);
      expect(find.text('1 題'), findsOneWidget);
      await tapText(tester, '開始');
      expect(find.text('語音改變了，檢定要重新開始。'), findsNothing);
    });

    testWidgets('作答中語音恢復：不重置', (tester) async {
      final backend = await arrange([choiceQuestion(), choiceQuestion()]);
      final container = await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
        settings: settingsFixture(silentMode: true),
      );
      await tapText(tester, '開始');
      await _answer(tester);

      await container
          .read(settingsProvider.notifier)
          .patch(settingsPatch(silentMode: false));
      await tester.pumpAndSettle();

      expect(_progress(), '第 2 題，共 2 題');
    });
  });

  testWidgets('P1 的 Esc 回到計畫（SA-12）', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(todayFixture());
    backend.drills.checkpointStartStub.returns([choiceQuestion()]);
    await pumpApp(
      tester,
      backend: backend,
      location: AppRoutes.sessionCheckpoint('ms.hira'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(PlanScreen), findsOneWidget);
  });
}
