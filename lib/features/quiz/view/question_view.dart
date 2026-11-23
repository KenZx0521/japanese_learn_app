import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/failures.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/local_log.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/tts/audio_available.dart';
import '../../../core/tts/autoplay.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/question_hint_strip.dart';
import '../bodies/choice_body.dart';
import '../bodies/match_body.dart';
import '../bodies/reorder_body.dart';
import '../bodies/self_grade_body.dart';
import '../bodies/shadow_body.dart';
import '../bodies/typing_body.dart';
import '../model/answer_clock.dart';
import '../model/feedback_plan.dart';
import '../model/question_hints.dart';
import '../model/quiz_run_state.dart';
import '../question_hint_controller.dart';
import 'question_prompt.dart';

/// 單題：操作提示、題幹、依 body 分派的作答元件。以題目位置為 key，換題時重建。
class QuestionView extends ConsumerStatefulWidget {
  const QuestionView({
    required this.question,
    required this.phase,
    required this.policy,
    required this.speechScope,
    required this.ratingPreviews,
    required this.expandVocab,
    required this.onAnswer,
    super.key,
  });

  final QuestionDto question;
  final QuizPhase phase;
  final DisplayPolicyDto policy;
  final String speechScope;
  final List<RatingPreviewDto> ratingPreviews;
  final bool expandVocab;
  final void Function(AnswerPayload payload, int durationMs) onAnswer;

  @override
  ConsumerState<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends ConsumerState<QuestionView> {
  final AnswerClock _clock = AnswerClock();
  late final bool _firstTimeType;
  bool _hintDismissed = false;
  bool _played = false;
  bool _voiceFailed = false;
  String? _silentError;

  QuestionDto get _question => widget.question;

  String get _promptId => '${widget.speechScope}/prompt';

  bool get _countsFromPlaybackEnd =>
      _question.questionType == QuestionType.kanaListen;

  SpeechRequest? get _promptRequest {
    final speech = _question.prompt.speech;
    return speech == null ? null : SpeechRequest.fromDto(_promptId, speech);
  }

  @override
  void initState() {
    super.initState();
    final type = _question.questionType;
    final hints = ref.read(questionHintsProvider.notifier);
    _firstTimeType = hints.shouldShow(type);
    if (_firstTimeType) {
      // 顯示當下就寫入，所以只出現一次（§3.12）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) hints.markShown(type);
      });
    }
  }

  void _onPlayback(TtsPlayback? previous, TtsPlayback next) {
    final wasSpeaking = previous is TtsSpeaking && previous.id == _promptId;
    if (next is TtsSpeaking && next.id == _promptId) {
      if (_countsFromPlaybackEnd) _clock.playbackStarted();
    } else if (next is TtsIdle && wasSpeaking) {
      if (_countsFromPlaybackEnd) _clock.playbackEnded();
      if (!_played) setState(() => _played = true);
    } else if (next is TtsError && next.id == _promptId) {
      if (_countsFromPlaybackEnd) _clock.playbackEnded();
      setState(() => _voiceFailed = true);
    }
  }

  void _retryVoice() {
    final request = _promptRequest;
    if (request == null) return;
    final tts = ref.read(ttsControllerProvider.notifier);
    setState(() => _voiceFailed = false);
    unawaited(tts.speak(tts.atUserSpeed(request)));
  }

  Future<void> _switchToSilent() async {
    try {
      await ref
          .read(settingsProvider.notifier)
          .patch(settingsPatch(silentMode: true));
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) setState(() => _silentError = failure.userMessage);
    }
  }

  void _answer(AnswerPayload payload) =>
      widget.onAnswer(payload, _clock.elapsedMs);

  PromptVoice _voice() {
    final needsPlayback = needsPlaybackOf(_question);
    final resolved = ref.watch(audioResolvedProvider);
    final available = ref.watch(audioAvailableProvider);
    return PromptVoice(
      request: _promptRequest,
      failed: _voiceFailed && needsPlayback,
      unavailable: needsPlayback && resolved && !available,
      onRetry: _retryVoice,
      onSilent: () => unawaited(_switchToSilent()),
      silentError: _silentError,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TtsPlayback>(ttsControllerProvider, _onPlayback);
    final request = _promptRequest;
    final prompt = QuestionPrompt(
      question: _question,
      policy: widget.policy,
      answered: widget.phase is QuizShowingFeedback,
      voice: _voice(),
    );
    final isSelfGrade = _question.body is QuestionBodyDto_SelfGrade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_firstTimeType && !_hintDismissed) ...[
          QuestionHintStrip(
            hint: questionHintFor(_question),
            onDismiss: () => setState(() => _hintDismissed = true),
          ),
          const SizedBox(height: AppSpace.s3),
        ],
        if (request != null)
          AutoplayOnce(request: request, enabled: _question.prompt.autoplay),
        if (!isSelfGrade) ...[prompt, const SizedBox(height: AppSpace.s5)],
        _body(prompt),
      ],
    );
  }

  Widget _body(Widget prompt) => switch (_question.body) {
    final QuestionBodyDto_Choice body => ChoiceBody(
      body: body,
      questionType: _question.questionType,
      policy: widget.policy,
      phase: widget.phase,
      onAnswer: _answer,
    ),
    final QuestionBodyDto_Reorder body => ReorderBody(
      body: body,
      phase: widget.phase,
      audioFirst: _question.prompt.hideTextUntilAnswered,
      promptPlayed: _played,
      onAnswer: _answer,
    ),
    final QuestionBodyDto_Typing body => TypingBody(
      body: body,
      phase: widget.phase,
      onAnswer: _answer,
    ),
    final QuestionBodyDto_Match body => MatchBody(
      body: body,
      seedKey: _question.reference.contentId,
      phase: widget.phase,
      onAnswer: _answer,
    ),
    final QuestionBodyDto_SelfGrade body => _selfGrade(body, prompt),
    QuestionBodyDto_Shadow() => ShadowBody(
      promptId: _promptId,
      phase: widget.phase,
      onAnswer: _answer,
    ),
  };

  Widget _selfGrade(QuestionBodyDto_SelfGrade body, Widget prompt) {
    final contentId = _question.reference.contentId;
    return SelfGradeBody(
      front: prompt,
      reveal: body.reveal,
      policy: widget.policy,
      phase: widget.phase,
      previews: widget.ratingPreviews,
      showHelpLine: _firstTimeType,
      speechId: '${widget.speechScope}/reveal',
      expandVocabId: widget.expandVocab && contentId.startsWith('vo.')
          ? contentId
          : null,
      onAnswer: _answer,
    );
  }
}
