import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/text/ruby_line.dart';
import '../../../core/text/word_peek.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../core/tts/voice_help.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/censor_bar.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/voice_failed_panel.dart';
import '../model/feedback_plan.dart';
import '../model/question_hints.dart';
import 'speak_row.dart';

/// 大字題幹的題型（§3.6）。其餘 `plain_text` 用內文字級。
bool _isHeroStem(QuestionType type) => switch (type) {
  QuestionType.kanaRead ||
  QuestionType.kanaConfuse ||
  QuestionType.kanaWord => true,
  QuestionType.recog ||
  QuestionType.vocabListen ||
  QuestionType.produce ||
  QuestionType.kanaListen ||
  QuestionType.kanaMatch ||
  QuestionType.minimalPair ||
  QuestionType.substitution ||
  QuestionType.reorder ||
  QuestionType.particleFill ||
  QuestionType.zhToJaChoice ||
  QuestionType.listenMeaning ||
  QuestionType.situationResponse ||
  QuestionType.conjugate ||
  QuestionType.registerConvert ||
  QuestionType.shadowing ||
  QuestionType.falseFriend => false,
};

/// 語音相關的外部狀態，一次傳給題幹。
@immutable
final class PromptVoice {
  const PromptVoice({
    required this.request,
    required this.failed,
    required this.unavailable,
    required this.onRetry,
    required this.onSilent,
    this.silentError,
  });

  final SpeechRequest? request;

  /// 播放失敗且本題要聽才能作答（tts §6.6）。
  final bool failed;

  /// 語音不可用，而本題要聽才能作答。
  final bool unavailable;
  final VoidCallback onRetry, onSilent;
  final String? silentError;
}

/// 題幹。`hide_text_until_answered` 時日文、假名、羅馬字都不進 widget tree（§3.6）。
class QuestionPrompt extends ConsumerWidget {
  const QuestionPrompt({
    required this.question,
    required this.policy,
    required this.answered,
    required this.voice,
    super.key,
  });

  final QuestionDto question;
  final DisplayPolicyDto policy;
  final bool answered;
  final PromptVoice voice;

  PromptDto get _prompt => question.prompt;

  bool get _hidden => _prompt.hideTextUntilAnswered && !answered;

  bool get _hasText => _prompt.text != null || _prompt.plainText != null;

  int? get _blankIndex {
    final body = question.body;
    return !answered && body is QuestionBodyDto_Choice
        ? body.blankWordIndex
        : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MixedText(
        instructionOf(question),
        color: AppTokens.of(context).ink.secondary,
      ),
      const SizedBox(height: AppSpace.s3),
      if (voice.failed && !answered)
        ..._failed(context)
      else
        ..._stem(context, ref),
    ],
  );

  List<Widget> _failed(BuildContext context) => [
    VoiceFailedPanel(onRetry: voice.onRetry, onSilent: voice.onSilent),
    if (voice.silentError case final error?) ...[
      const SizedBox(height: AppSpace.s2),
      AppText(error, scale: TypeScale.caption),
    ],
  ];

  /// 大字題幹把播放鈕放在同一列：答完才出現也不會把選項往下擠。
  bool get _speakBesideHero =>
      _isHeroStem(question.questionType) &&
      !_hidden &&
      _prompt.plainText != null;

  List<Widget> _stem(BuildContext context, WidgetRef ref) => [
    if (_speakBesideHero)
      ..._heroWithSpeak(context)
    else ...[
      if (!_hidden) ..._visibleTexts(context),
      if (_showSpeak) _speakRow(),
    ],
    if (_hidden && _hasText) CensorBar(characters: _hiddenLength(ref)),
    if (voice.unavailable && !answered) _VoiceHelpNote(voice: voice),
  ];

  bool get _showSpeak =>
      voice.request != null &&
      (answered || speechAllowedBeforeAnswer(question.questionType));

  List<Widget> _heroWithSpeak(BuildContext context) => [
    Row(
      children: [
        Expanded(child: _plainLine() ?? const SizedBox.shrink()),
        if (_showSpeak) ...[const SizedBox(width: AppSpace.s3), _speakRow()],
      ],
    ),
    if (_prompt.text != null) ...[
      const SizedBox(height: AppSpace.s2),
      ?_sentenceLine(context),
    ],
    const SizedBox(height: AppSpace.s2),
  ];

  Widget _speakRow() {
    final request = voice.request;
    if (request == null) return const SizedBox.shrink();
    return SpeakRow(
      request: request,
      diameter: _hasText && !_hidden ? 48 : 72,
      replayOnR: true,
    );
  }

  /// 只拿長度，文字本身不放進 tree。
  int _hiddenLength(WidgetRef ref) {
    final text = _prompt.text;
    if (text != null) return text.display.length;
    final tools = ref.watch(textToolsProvider);
    return tools
        .parseMixedText(_prompt.plainText ?? '')
        .fold(0, (sum, span) => sum + _spanLength(span));
  }

  static int _spanLength(MixedSpanDto span) => switch (span) {
    MixedSpanDto_Zh(:final text) || MixedSpanDto_Ja(:final text) => text.length,
  };

  List<Widget> _visibleTexts(BuildContext context) {
    final sentence = _sentenceLine(context);
    final plain = _plainLine();
    // 語體轉換先看原句，再看目標語體；其餘是中文提示在上（§3.6）
    final textFirst = question.questionType == QuestionType.registerConvert;
    return [
      if (textFirst && sentence != null) sentence,
      ?plain,
      if (!textFirst && sentence != null) sentence,
      const SizedBox(height: AppSpace.s2),
    ];
  }

  Widget? _sentenceLine(BuildContext context) {
    final text = _prompt.text;
    if (text == null) return null;
    return RubyLine.sentence(
      text,
      policy: policy,
      blankWordIndex: _blankIndex,
      onWordTap: (word) => unawaited(showWordPeek(context, word)),
    );
  }

  Widget? _plainLine() {
    final plain = _prompt.plainText;
    if (plain == null) return null;
    if (!_isHeroStem(question.questionType)) return MixedText(plain);
    // 較長的實字在窄螢幕縮小而不是斷行
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: MixedText(plain, scale: TypeScale.jaHero),
    );
  }
}

class _VoiceHelpNote extends StatelessWidget {
  const _VoiceHelpNote({required this.voice});
  final PromptVoice voice;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText('這題要聽聲音，現在無法播放。'),
        const SizedBox(height: AppSpace.s2),
        GhostButton(
          label: '查看語音說明',
          onPressed: () => unawaited(showVoiceHelpSheet(context)),
        ),
      ],
    ),
  );
}
