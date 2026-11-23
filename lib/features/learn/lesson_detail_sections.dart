import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../core/text/policy_romaji.dart';
import '../../core/tts/tts_engine.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/genko_grid.dart';
import '../../design/widgets/ja_word_line.dart';
import '../../design/widgets/kana_cell.dart';
import '../../design/widgets/ruled_list.dart';
import '../../design/widgets/speak_button.dart';
import '../dialogue/view/dialogue_summary_tile.dart';

/// L2 的內容區塊。窄版全部疊在主欄，單字放最後（一課有二十幾個字，
/// 放前面會把文法和對話擠到很下面）；寬版規則卡、對話、文法移到右欄。
class LessonDetailSections extends StatelessWidget {
  const LessonDetailSections.all({
    required this.detail,
    required this.romajiMode,
    super.key,
  }) : _slots = const [
         _Slot.kana,
         _Slot.rules,
         _Slot.dialogue,
         _Slot.grammar,
         _Slot.words,
       ];

  const LessonDetailSections.main({
    required this.detail,
    required this.romajiMode,
    super.key,
  }) : _slots = const [_Slot.kana, _Slot.words];

  const LessonDetailSections.aside({required this.detail, super.key})
    : romajiMode = null,
      _slots = const [_Slot.rules, _Slot.dialogue, _Slot.grammar];

  final LessonDetailDto detail;
  final RomajiMode? romajiMode;
  final List<_Slot> _slots;

  Widget? _sectionOf(_Slot slot) => switch (slot) {
    _Slot.kana when detail.kana.isNotEmpty => _Section(
      title: '假名',
      count: detail.kana.length,
      child: GenkoGrid(
        maxCell: _maxKanaCell,
        children: [
          for (final cell in detail.kana)
            KanaCell(kana: cell.ch, romaji: cell.romaji, status: cell.status),
        ],
      ),
    ),
    _Slot.rules when detail.rules.isNotEmpty => _Section(
      title: '規則卡',
      count: detail.rules.length,
      child: RuledList(
        children: [for (final rule in detail.rules) _RuleRow(rule: rule)],
      ),
    ),
    _Slot.dialogue when detail.dialogue != null => _Section(
      title: '對話',
      child: RuledList(
        children: [DialogueSummaryTile(dialogue: detail.dialogue!)],
      ),
    ),
    _Slot.grammar when detail.grammar.isNotEmpty => _Section(
      title: '文法',
      count: detail.grammar.length,
      child: RuledList(
        children: [for (final item in detail.grammar) _GrammarRow(item: item)],
      ),
    ),
    _Slot.words when detail.words.isNotEmpty => _Section(
      title: '新字',
      count: detail.words.length,
      child: RuledList(
        children: [
          for (final word in detail.words)
            _WordRow(word: word, romajiMode: romajiMode),
        ],
      ),
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final slot in _slots) ?_sectionOf(slot)],
  );
}

enum _Slot { kana, rules, dialogue, grammar, words }

/// 一課只有幾個假名，寬螢幕時不放大成半頁高的格子。
const _maxKanaCell = 72.0;

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.count});

  final String title;
  final int? count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = count;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(header: true, child: EyebrowText(title)),
              if (total != null) ...[
                const SizedBox(width: AppSpace.s2),
                AppText(
                  '$total',
                  scale: TypeScale.label,
                  color: AppTokens.of(context).ink.secondary,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          child,
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule});

  final RuleCardDto rule;

  @override
  Widget build(BuildContext context) => RuledTile(
    title: MixedText(rule.titleZh),
    onTap: () => unawaited(context.push(AppRoutes.kanaRule(rule.id))),
  );
}

class _GrammarRow extends StatelessWidget {
  const _GrammarRow({required this.item});

  final GrammarSummaryDto item;

  @override
  Widget build(BuildContext context) => RuledTile(
    title: MixedText(item.titleZh),
    subtitle: MixedText(
      item.meaningZh,
      scale: TypeScale.caption,
      color: AppTokens.of(context).ink.secondary,
    ),
    onTap: () => unawaited(context.push(AppRoutes.grammarPoint(item.id))),
  );
}

/// 羅馬字依 [romajiMode]（該課的 `display_policy`），讀不到規則時先不顯示。
class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.romajiMode});

  final VocabSummaryDto word;
  final RomajiMode? romajiMode;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final mode = romajiMode;
    return RuledTile(
      title: Wrap(
        spacing: AppSpace.s3,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          JaWordLine(word.surface, scale: TypeScale.jaSentence),
          if (word.kana != word.surface)
            JaWordLine(word.kana, color: t.ink.secondary),
          if (mode != null) PolicyRomaji(word.romaji, mode: mode),
        ],
      ),
      subtitle: AppText(
        word.zh.join('、'),
        scale: TypeScale.caption,
        color: t.ink.secondary,
      ),
      trailing: SpeakButton(
        request: SpeechRequest.fromDto(word.id, word.speech),
      ),
      onTap: () => unawaited(context.push(AppRoutes.vocabWord(word.id))),
    );
  }
}
