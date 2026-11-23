import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

/// 全部題型都已看過提示，測其他行為時不被提示列干擾。
SettingsDto allHintsSeen({bool showIntervals = false, bool autoplay = true}) =>
    applyPatch(
      settingsFixture(autoplay: autoplay),
      settingsPatch(
        seenQuestionHints: QuestionType.values,
        showRatingIntervals: showIntervals,
      ),
    );

Future<ProviderContainer> pumpQuiz(
  WidgetTester tester,
  List<QuestionDto> questions, {
  required FakeBackend backend,
  FakeTtsEngine? tts,
  QuizGrader grader = const DrillGrader(),
  ValueChanged<QuizOutcome>? onFinished,
  bool requeueWrong = false,
  SettingsDto? settings,
  List<RatingPreviewDto> previews = const [],
  bool expandVocab = false,
  double width = 375,
  double height = 800,
  double textScale = 1,
  bool settle = true,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
  bool inline = false,
}) {
  final resolved = settings ?? allHintsSeen();
  backend.settings.current = resolved;
  final view = QuizSessionView(
    questions: questions,
    grader: grader,
    onFinished: onFinished ?? (_) {},
    fallbackLessonId: 'le.l01',
    requeueWrong: requeueWrong,
    ratingPreviews: previews,
    expandVocab: expandVocab,
  );
  return pumpApp(
    tester,
    backend: backend,
    tts: tts,
    settings: resolved,
    width: width,
    height: height,
    textScale: textScale,
    settle: settle,
    disableAnimations: disableAnimations,
    accessibleNavigation: accessibleNavigation,
    child: inline ? SingleChildScrollView(child: view) : view,
  );
}

/// 測試自己組的外層（例如換一批題目）。
Future<ProviderContainer> pumpQuizChild(
  WidgetTester tester,
  FakeBackend backend,
  Widget child,
) {
  final settings = allHintsSeen();
  backend.settings.current = settings;
  return pumpApp(tester, backend: backend, settings: settings, child: child);
}

/// 有無限動畫（播放中的音波、準備中的細環）時不能用 pumpAndSettle。
Future<void> settleFrames(WidgetTester tester) async {
  const frames = 12;
  for (var i = 0; i < frames; i++) {
    await tester.pump();
  }
}
