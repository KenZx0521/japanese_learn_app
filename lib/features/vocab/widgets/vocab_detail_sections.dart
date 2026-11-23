import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/text/ja_text.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/text/ruby_line.dart';
import '../../../core/text/word_peek.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/note_body.dart';
import '../../../design/widgets/ruled_list.dart';
import '../../../design/widgets/side_rule_note.dart';
import '../../../design/widgets/speak_button.dart';

/// V3 各區塊（§3.4）。沒有內容的區塊整段不顯示。
List<Widget> vocabDetailSections(
  BuildContext context, {
  required VocabDetailDto detail,
  required DisplayPolicyDto policy,
}) {
  void openWord(String id) => context.push(AppRoutes.vocabWord(id));
  void openGrammar(String id) => context.push(AppRoutes.grammarPoint(id));
  return [
    if (detail.hookZh case final hook?)
      _spaced(SideRuleNote(title: '記法', child: MixedText(hook))),
    if (detail.trapZh case final trap?)
      _spaced(
        SideRuleNote(
          title: '容易錯',
          tone: SideRuleTone.shu,
          child: MixedText(trap),
        ),
      ),
    if (detail.pair case final pair?)
      _section('自他成對', _RefList(refs: [pair], onOpen: openWord)),
    if (detail.readingFamily.isNotEmpty)
      _section('同字異讀', _RefList(refs: detail.readingFamily, onOpen: openWord)),
    if (detail.conjugations.isNotEmpty)
      _section('活用', _ConjugationTable(rows: detail.conjugations)),
    if (detail.examples.isNotEmpty)
      _section(
        '例句',
        _ExampleList(
          examples: detail.examples,
          policy: policy,
          onOpenWord: openWord,
        ),
      ),
    if (detail.notes.isNotEmpty)
      _section(
        '筆記',
        _NoteList(
          notes: detail.notes,
          onOpenWord: openWord,
          onOpenGrammar: openGrammar,
        ),
      ),
  ];
}

Widget _spaced(Widget child) => Padding(
  padding: const EdgeInsets.only(top: AppSpace.s4),
  child: child,
);

Widget _section(String title, Widget child) => Padding(
  padding: const EdgeInsets.only(top: AppSpace.s6),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(header: true, child: EyebrowText(title)),
      const SizedBox(height: AppSpace.s3),
      child,
    ],
  ),
);

class _NoteList extends StatelessWidget {
  const _NoteList({
    required this.notes,
    required this.onOpenWord,
    required this.onOpenGrammar,
  });

  final List<NoteDto> notes;
  final ValueChanged<String> onOpenWord, onOpenGrammar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final note in notes)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s5),
          child: NoteBody(
            note: note,
            onOpenVocab: onOpenWord,
            onOpenGrammar: onOpenGrammar,
          ),
        ),
    ],
  );
}

class _RefList extends StatelessWidget {
  const _RefList({required this.refs, required this.onOpen});

  final List<VocabRefDto> refs;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return RuledList(
      children: [
        for (final ref in refs)
          RuledTile(
            onTap: () => onOpen(ref.id),
            title: Wrap(
              spacing: AppSpace.s3,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                JaText(ref.surface),
                if (ref.kana != ref.surface)
                  JaText(ref.kana, color: t.ink.secondary),
              ],
            ),
            subtitle: AppText(
              ref.zh.join('、'),
              scale: TypeScale.caption,
              color: t.ink.secondary,
            ),
          ),
      ],
    );
  }
}

class _ConjugationTable extends StatelessWidget {
  const _ConjugationTable({required this.rows});

  final List<ConjugationDto> rows;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: Wrap(
              spacing: AppSpace.s4,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                MixedText(row.form, color: t.ink.secondary),
                JaText(row.surface),
                if (row.kana != row.surface)
                  JaText(row.kana, color: t.ink.secondary),
              ],
            ),
          ),
      ],
    );
  }
}

class _ExampleList extends StatelessWidget {
  const _ExampleList({
    required this.examples,
    required this.policy,
    required this.onOpenWord,
  });

  final List<SentenceDto> examples;
  final DisplayPolicyDto policy;
  final ValueChanged<String> onOpenWord;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final example in examples)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s4),
          child: _ExampleItem(
            example: example,
            policy: policy,
            onOpenWord: onOpenWord,
          ),
        ),
    ],
  );
}

class _ExampleItem extends StatelessWidget {
  const _ExampleItem({
    required this.example,
    required this.policy,
    required this.onOpenWord,
  });

  final SentenceDto example;
  final DisplayPolicyDto policy;
  final ValueChanged<String> onOpenWord;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RubyLine.sentence(
        example,
        policy: policy,
        onWordTap: (word) => showWordPeek(
          context,
          word,
          onOpenDetail: (id) {
            if (id.startsWith('vo.')) onOpenWord(id);
          },
        ),
      ),
      AppText(example.zh, color: AppTokens.of(context).ink.secondary),
      SpeakButton(request: SpeechRequest.fromDto(example.id, example.speech)),
    ],
  );
}
