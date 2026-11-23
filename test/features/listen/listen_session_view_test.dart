import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/design/widgets/paper_scaffold.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/features/listen/listen.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

const _logicalDate = '2026-03-02';

SettingsDto _hintsSeen({bool silent = false}) => applyPatch(
  settingsFixture(silentMode: silent),
  settingsPatch(seenQuestionHints: QuestionType.values),
);

QuestionDto _shadowQuestion() => QuestionDto(
  questionType: QuestionType.shadowing,
  reference: const QuestionRefDto(
    questionType: QuestionType.shadowing,
    contentId: 'se.l01.001',
  ),
  prompt: PromptDto(
    instructionZh: '聽完跟著念',
    text: sentenceFixture(),
    speech: sentenceFixture().speech,
    autoplay: true,
    hideTextUntilAnswered: false,
  ),
  body: QuestionBodyDto.shadow(reveal: sentenceFixture()),
  focusIds: const [],
);

Widget _view({
  ValueChanged<QuizOutcome>? onFinished,
  VoidCallback? onEmpty,
  VoidCallback? onSkipFailed,
}) => PaperScaffold(
  scrollable: false,
  body: ListenSessionView(
    taskKey: 'listen',
    seed: sessionSeed(_logicalDate),
    fallbackLessonId: 'le.l01',
    onFinished: onFinished ?? (_) {},
    onEmpty: onEmpty ?? () {},
    onSkipFailed: onSkipFailed,
  ),
);

void main() {
  testWidgets('答錯的題目本回合末重出（D2 版面）', (tester) async {
    final backend = FakeBackend();
    backend.today.listenSessionStub.returns([_shadowQuestion()]);

    await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(autoComplete: false),
      disableAnimations: true,
      settings: _hintsSeen(),
      child: _view(),
    );

    expect(
      tester.widget<QuizSessionView>(find.byType(QuizSessionView)).requeueWrong,
      isTrue,
    );
  });

  testWidgets('以任務 key 與傳入的 seed 取題', (tester) async {
    final backend = FakeBackend();
    backend.today.listenSessionStub.returns([_shadowQuestion()]);

    await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(autoComplete: false),
      disableAnimations: true,
      settings: _hintsSeen(),
      child: _view(),
    );

    expect(backend.today.listenSessionStub.calls.single, [
      'listen',
      sessionSeed(_logicalDate),
      true,
    ]);
    expect(find.byType(QuizSessionView), findsOneWidget);
  });

  testWidgets('跟讀三級自評只走 grade_drill，帶回原 reference', (tester) async {
    final backend = FakeBackend();
    final question = _shadowQuestion();
    backend.today.listenSessionStub.returns([question]);
    backend.drills.gradeStub.returns(
      const DrillResultDto(isCorrect: true, correctDisplay: ''),
    );
    QuizOutcome? outcome;

    await pumpApp(
      tester,
      backend: backend,
      settings: _hintsSeen(),
      child: _view(onFinished: (result) => outcome = result),
      settle: false,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('差一點'));
    await tester.pumpAndSettle();

    final call = backend.drills.gradeStub.calls.single;
    expect(call.first, question.reference);
    expect(call.last, const AnswerPayload.shadow(level: ShadowLevel.almost));
    expect(backend.review.submitStub.calls, isEmpty);

    expect(outcome?.records, hasLength(1));
  });

  testWidgets('語音探測完成前不呼叫 listen_session', (tester) async {
    final backend = FakeBackend();
    final probe = Completer<void>();

    await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(probeGate: probe.future),
      settings: _hintsSeen(),
      child: _view(),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(backend.today.listenSessionStub.calls, isEmpty);
    expect(find.byType(SkeletonLines), findsOneWidget);

    probe.complete();
    await tester.pumpAndSettle();
    expect(backend.today.listenSessionStub.calls, hasLength(1));
  });

  testWidgets('有語音但沒題目時自動略過', (tester) async {
    var empty = 0;

    await pumpApp(
      tester,
      settings: _hintsSeen(),
      child: _view(onEmpty: () => empty++),
    );

    expect(empty, 1);
  });

  testWidgets('沒語音時說明原因並給設定入口，不自動略過', (tester) async {
    final backend = FakeBackend();
    var empty = 0;

    await pumpApp(
      tester,
      backend: backend,
      settings: _hintsSeen(silent: true),
      child: _view(onEmpty: () => empty++),
    );

    expect(backend.today.listenSessionStub.calls.single.last, isFalse);
    expect(empty, 0);
    expect(find.text('現在沒有語音，聽力先略過。'), findsOneWidget);

    await tester.tap(find.text('略過這一項'));
    await tester.pump();
    expect(empty, 1);
  });

  testWidgets('沒語音時可開語音說明', (tester) async {
    await pumpApp(tester, settings: _hintsSeen(silent: true), child: _view());

    await tester.tap(find.text('設定語音'));
    await tester.pumpAndSettle();

    expect(find.text('無聲模式開著'), findsOneWidget);
  });

  testWidgets('載入失敗可重試', (tester) async {
    final backend = FakeBackend();
    backend.today.listenSessionStub.throws(const StorageFailure());

    await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(autoComplete: false),
      disableAnimations: true,
      settings: _hintsSeen(),
      child: _view(),
    );
    expect(find.text(const StorageFailure().userMessage), findsOneWidget);
    expect(find.text('略過這一項'), findsNothing);

    backend.today.listenSessionStub.returns([_shadowQuestion()]);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizSessionView), findsOneWidget);
  });

  testWidgets('T2 傳入略過動作時，失敗可略過', (tester) async {
    final backend = FakeBackend();
    backend.today.listenSessionStub.throws(const StorageFailure());
    var skipped = 0;

    await pumpApp(
      tester,
      backend: backend,
      settings: _hintsSeen(),
      child: _view(onSkipFailed: () => skipped++),
    );

    await tester.tap(find.text('略過這一項'));
    await tester.pump();

    expect(skipped, 1);
  });
}
