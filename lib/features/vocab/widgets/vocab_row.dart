import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ja_word_line.dart';
import '../../../design/widgets/ruled_list.dart';
import '../../../design/widgets/speak_button.dart';
import '../vocab_labels.dart';
import '../vocab_providers.dart';

/// V1、V2 的單字列（§3.4）：一行一字，左單字、中間假名、右狀態與播放鈕。
class VocabRow extends ConsumerWidget {
  const VocabRow({required this.word, super.key});

  final VocabSummaryDto word;

  static const _compactScale = 1.5;

  /// 未介紹的字淡色顯示，仍可點開。
  bool _isFaded(VocabFlagsDto flags) =>
      word.srsState == SrsStateLabel.notStarted && !flags.known;

  String _statusLabel(VocabFlagsDto flags) {
    final status = flags.known ? '已會' : srsLabelOf(word.srsState);
    return flags.starred ? '$status · 收藏' : status;
  }

  String get _caption {
    final lesson = lessonLabelOf(word.lessonId);
    final meaning = word.zh.join('、');
    return lesson.isEmpty ? meaning : '$meaning · $lesson';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final flags = vocabFlagsOf(ref, word);
    // 大字級時右側狀態欄會把單字擠到很小，改放到說明行，右邊只留播放鈕
    final compact = MediaQuery.textScalerOf(context).scale(1) >= _compactScale;
    final speak = SpeakButton(
      request: SpeechRequest.fromDto(word.id, word.speech),
    );
    return RuledTile(
      onTap: () => context.push(AppRoutes.vocabWord(word.id)),
      title: Wrap(
        spacing: AppSpace.s3,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          JaWordLine(
            word.surface,
            scale: TypeScale.jaSentence,
            color: _isFaded(flags) ? t.ink.tertiary : t.ink.primary,
          ),
          if (word.kana != word.surface)
            JaWordLine(word.kana, color: t.ink.secondary),
        ],
      ),
      subtitle: AppText(
        compact ? '$_caption · ${_statusLabel(flags)}' : _caption,
        scale: TypeScale.caption,
        color: t.ink.secondary,
      ),
      trailing: compact
          ? speak
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusColumn(state: word.srsState, flags: flags),
                const SizedBox(width: AppSpace.s2),
                speak,
              ],
            ),
    );
  }
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn({required this.state, required this.flags});

  final SrsStateLabel state;
  final VocabFlagsDto flags;

  Color _color(AppTokens t) {
    if (flags.known || state == SrsStateLabel.review) return t.ink.secondary;
    return switch (state) {
      SrsStateLabel.notStarted => t.ink.tertiary,
      SrsStateLabel.learning => t.ai,
      SrsStateLabel.review => t.ink.secondary,
      SrsStateLabel.mastered => t.moegi,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppText(
          flags.known ? '已會' : srsLabelOf(state),
          scale: TypeScale.caption,
          color: _color(t),
        ),
        if (flags.starred)
          AppText('收藏', scale: TypeScale.caption, color: t.kincha),
      ],
    );
  }
}
