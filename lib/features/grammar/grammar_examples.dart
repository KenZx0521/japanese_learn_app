import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/display_context.dart';
import '../../core/text/ruby_line.dart';
import '../../core/text/word_peek.dart';
import '../../core/tts/tts_engine.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/speak_button.dart';

/// 例句：先顯示 3 句，其餘展開（§3.5）。每句可播放、可點字查詢。
class GrammarExamples extends ConsumerStatefulWidget {
  const GrammarExamples({
    required this.examples,
    required this.lessonId,
    super.key,
  });

  final List<SentenceDto> examples;
  final String lessonId;

  @override
  ConsumerState<GrammarExamples> createState() => _GrammarExamplesState();
}

class _GrammarExamplesState extends ConsumerState<GrammarExamples> {
  static const _initialCount = 3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = displayPolicyProvider(
      DisplayContext(lessonId: widget.lessonId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EyebrowText('例句'),
        const SizedBox(height: AppSpace.s2),
        AsyncBody<DisplayPolicyDto>(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          data: _sentences,
        ),
      ],
    );
  }

  Widget _sentences(DisplayPolicyDto policy) {
    final all = widget.examples;
    final shown = _expanded ? all : all.take(_initialCount).toList();
    final hidden = all.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final sentence in shown)
          _ExampleRow(sentence: sentence, policy: policy),
        if (hidden > 0) ...[
          const SizedBox(height: AppSpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: GhostButton(
              label: '再看 $hidden 句',
              onPressed: () => setState(() => _expanded = true),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.sentence, required this.policy});

  final SentenceDto sentence;
  final DisplayPolicyDto policy;

  void _peek(BuildContext context, WordDto word) => unawaited(
    showWordPeek(context, word, onOpenDetail: (id) => _openDetail(context, id)),
  );

  /// 先關面板再跳轉；`ka.*` 沒有單字頁，回五十音表。
  void _openDetail(BuildContext context, String id) {
    Navigator.of(context).pop();
    final path = switch (id) {
      _ when id.startsWith('vo.') => AppRoutes.vocabWord(id),
      _ when id.startsWith('gr.') => AppRoutes.grammarPoint(id),
      _ when id.startsWith('ka.') => AppRoutes.kana,
      _ => null,
    };
    if (path != null) unawaited(context.push(path));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line.grid)),
      ),
      // 日文佔滿整行，換行才會落在詞界（§7.3）；播放鈕放在中文那一行
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RubyLine.sentence(
            sentence,
            policy: policy,
            onWordTap: (word) => _peek(context, word),
          ),
          const SizedBox(height: AppSpace.s1),
          Row(
            children: [
              Expanded(child: AppText(sentence.zh, color: t.ink.secondary)),
              const SizedBox(width: AppSpace.s2),
              SpeakButton(
                request: SpeechRequest.fromDto(sentence.id, sentence.speech),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
