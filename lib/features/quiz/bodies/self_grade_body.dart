import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/text/ruby_line.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/flip_card.dart';
import '../../../design/widgets/rating_bar.dart';
import '../model/quiz_run_state.dart';
import '../view/speak_row.dart';
import '../view/vocab_expansion.dart';

/// 自評題（§3.4）：點卡片或空白鍵翻面，評分列只在翻面後出現。
class SelfGradeBody extends ConsumerStatefulWidget {
  const SelfGradeBody({
    required this.front,
    required this.reveal,
    required this.policy,
    required this.phase,
    required this.previews,
    required this.showHelpLine,
    required this.speechId,
    required this.onAnswer,
    this.expandVocabId,
    super.key,
  });

  final Widget front;
  final SentenceDto reveal;
  final DisplayPolicyDto policy;
  final QuizPhase phase;
  final List<RatingPreviewDto> previews;
  final bool showHelpLine;
  final String speechId;
  final ValueChanged<AnswerPayload> onAnswer;

  /// 非 null 時在背面展開單字（§3.4 第 4 點）。
  final String? expandVocabId;

  @override
  ConsumerState<SelfGradeBody> createState() => _SelfGradeBodyState();
}

class _SelfGradeBodyState extends ConsumerState<SelfGradeBody> {
  bool _flipped = false;

  void _flip() => setState(() => _flipped = true);

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (_flipped ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    _flip();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final showIntervals = ref.watch(
      settingsProvider.select((s) => s.value?.showRatingIntervals ?? false),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: FlipCard(
            flipped: _flipped,
            onFlip: _flipped ? null : _flip,
            front: _Face(child: _front()),
            // 翻面前不建背面，答案才不會出現在 widget tree（reduced motion 的交叉淡入也一樣）
            back: _flipped ? _Face(child: _back()) : const SizedBox.shrink(),
          ),
        ),
        if (_flipped && widget.phase is QuizAnswering) ...[
          const SizedBox(height: AppSpace.s4),
          RatingBar(
            previews: widget.previews,
            showIntervals: showIntervals,
            showHelpLine: widget.showHelpLine,
            onRate: (rating) =>
                widget.onAnswer(AnswerPayload.selfGrade(rating: rating)),
          ),
        ],
      ],
    );
  }

  Widget _front() {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.front,
        const SizedBox(height: AppSpace.s4),
        AppText('翻面看答案', scale: TypeScale.label, color: t.ink.secondary),
      ],
    );
  }

  Widget _back() {
    final t = AppTokens.of(context);
    final reveal = widget.reveal;
    final vocabId = widget.expandVocabId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reveal.words.isEmpty)
          // 沒有例句時 Rust 給的是項目標題（中文夾假名），不是日文句子
          MixedText(reveal.display, scale: TypeScale.title)
        else
          RubyLine.sentence(reveal, policy: widget.policy),
        if (reveal.zh.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s2),
          AppText(reveal.zh, color: t.ink.secondary),
        ],
        if (reveal.speech.text.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s2),
          SpeakRow(
            request: SpeechRequest.fromDto(widget.speechId, reveal.speech),
          ),
        ],
        if (vocabId != null) ...[
          const SizedBox(height: AppSpace.s4),
          VocabExpansion(
            vocabId: vocabId,
            policy: widget.policy,
            showHead: false,
          ),
        ],
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 140),
    padding: const EdgeInsets.all(AppSpace.s4),
    child: child,
  );
}
