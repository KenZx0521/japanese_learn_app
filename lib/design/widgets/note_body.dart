import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/text/ja_text.dart';
import '../../core/text/mixed_text.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'ink_buttons.dart';
import 'side_rule_note.dart';

/// 五種筆記的呈現（§3.11），用 switch 窮舉 sealed `NoteDto`。
class NoteBody extends StatelessWidget {
  const NoteBody({
    required this.note,
    this.onOpenVocab,
    this.onOpenGrammar,
    super.key,
  });

  final NoteDto note;
  final ValueChanged<String>? onOpenVocab;
  final ValueChanged<String>? onOpenGrammar;

  @override
  Widget build(BuildContext context) => switch (note) {
    NoteDto_FalseFriend() => _FalseFriendBody(
      note: note as NoteDto_FalseFriend,
      onOpenVocab: onOpenVocab,
    ),
    NoteDto_Shinjitai() => _ShinjitaiBody(note: note as NoteDto_Shinjitai),
    NoteDto_Reading() => _ReadingBody(note: note as NoteDto_Reading),
    NoteDto_Transfer() => _TransferBody(note: note as NoteDto_Transfer),
    NoteDto_Term() => _TermBody(
      note: note as NoteDto_Term,
      onOpenGrammar: onOpenGrammar,
    ),
  };
}

class _FalseFriendBody extends StatelessWidget {
  const _FalseFriendBody({required this.note, this.onOpenVocab});
  final NoteDto_FalseFriend note;
  final ValueChanged<String>? onOpenVocab;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final open = onOpenVocab;
    final vocabId = note.vocabId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JaText(note.surface, scale: TypeScale.jaSentence),
        const SizedBox(height: AppSpace.s2),
        _LabeledLine(label: '日文意思', value: note.jaZh),
        _LabeledLine(label: '容易誤解成', value: note.misreadZh, color: t.shu),
        if (open != null && vocabId != null)
          GhostButton(label: '看單字', onPressed: () => open(vocabId)),
      ],
    );
  }
}

class _LabeledLine extends StatelessWidget {
  const _LabeledLine({required this.label, required this.value, this.color});
  final String label, value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s1),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          scale: TypeScale.caption,
          color: AppTokens.of(context).ink.secondary,
        ),
        MixedText(value, color: color),
      ],
    ),
  );
}

/// 字形對照的四種 `kind`（curriculum §2 T2）。和製漢字在台灣沒有對應字，
/// `zh_tw` 放的是意思最接近的中文字，所以標籤不能寫「對照」。
/// `variant_split`：日文依意思分成兩個並存的字（着／著），台灣只用一個字。
const _kokujiKind = 'kokuji';

String _shinjitaiPairLabel(String kind) => kind == _kokujiKind ? '意思近' : '對照';

String? _shinjitaiCaption(String kind) => switch (kind) {
  'simplified_differently' => '日本的新字體，和台灣的寫法不同',
  'shape_detail' => '同一個字，日本和台灣的筆畫細節不同',
  'variant_split' => '日文依意思分成兩個字，這個意思寫左邊的字；台灣都寫右邊的字',
  _kokujiKind => '日本自創的漢字，台灣不用；右邊是意思最接近的中文字',
  _ => null,
};

class _ShinjitaiBody extends StatelessWidget {
  const _ShinjitaiBody({required this.note});
  final NoteDto_Shinjitai note;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final caption = _shinjitaiCaption(note.kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            JaText(note.ja, scale: TypeScale.jaHero),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: AppText(
                _shinjitaiPairLabel(note.kind),
                scale: TypeScale.caption,
                color: t.ink.secondary,
              ),
            ),
            // 內容字串不用 displayM：Noto Serif TC 只打包 lib/ 用字（§4.2）
            AppText(note.zhTw, scale: TypeScale.title),
          ],
        ),
        if (caption != null)
          AppText(caption, scale: TypeScale.caption, color: t.ink.secondary),
      ],
    );
  }
}

/// 台語讀音一律寫台羅數字調（RULINGS O10），畫面上說明數字的意思。
const _taiLegend = '台語讀音為台羅拼音，字尾數字是聲調';

class _ReadingBody extends StatelessWidget {
  const _ReadingBody({required this.note});
  final NoteDto_Reading note;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MixedText(note.titleZh, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s2),
        MixedText(note.bodyZh),
        if (note.examples.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s2),
            child: AppText(
              _taiLegend,
              scale: TypeScale.caption,
              color: t.ink.secondary,
            ),
          ),
        for (final example in note.examples)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s2),
            child: Wrap(
              spacing: AppSpace.s3,
              children: [
                AppText(example.hanzi),
                AppText(example.tai, color: t.ink.secondary),
                MixedText(example.ja),
              ],
            ),
          ),
        const SizedBox(height: AppSpace.s3),
        SideRuleNote(title: '提醒', child: MixedText(note.caveatZh)),
      ],
    );
  }
}

class _TransferBody extends StatelessWidget {
  const _TransferBody({required this.note});
  final NoteDto_Transfer note;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final struck = TypeScale.jaBody
        .style(t.shu)
        .copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: t.shu,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MixedText(note.titleZh, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s2),
        AppText(note.zhPattern, color: t.ink.secondary),
        const SizedBox(height: AppSpace.s2),
        DefaultTextStyle.merge(
          style: struck,
          child: MixedText(note.wrong, color: t.shu),
        ),
        MixedText(note.right),
        const SizedBox(height: AppSpace.s2),
        MixedText(note.explainZh),
      ],
    );
  }
}

class _TermBody extends StatelessWidget {
  const _TermBody({required this.note, this.onOpenGrammar});
  final NoteDto_Term note;
  final ValueChanged<String>? onOpenGrammar;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final open = onOpenGrammar;
    final aka = note.akaZh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MixedText(note.term, scale: TypeScale.title),
        // `aka_zh` 是 *_zh 欄位，可含 {ja:} 標記（§7 MixedText 適用欄位）
        if (aka != null)
          MixedText(aka, scale: TypeScale.caption, color: t.ink.secondary),
        const SizedBox(height: AppSpace.s2),
        MixedText(note.bodyZh),
        if (open != null)
          Wrap(
            spacing: AppSpace.s2,
            children: [
              for (final id in note.grammarIds)
                GhostButton(label: '看文法', onPressed: () => open(id)),
            ],
          ),
      ],
    );
  }
}
