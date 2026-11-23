import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/note_body.dart';
import '../../design/widgets/ruled_list.dart';
import '../../design/widgets/sheet_frame.dart';

/// 相關術語（§3.5）：點開底部面板看說明，下方連到筆記頁的術語分頁。
class GrammarTerms extends StatelessWidget {
  const GrammarTerms({required this.terms, super.key});

  final List<NoteDto> terms;

  /// `terms` 依內容規則只會是 `no.term.*`，其他種類的筆記不在這裡呈現。
  Iterable<NoteDto_Term> get _termNotes => terms.whereType<NoteDto_Term>();

  void _open(BuildContext context, NoteDto_Term note) => unawaited(
    showPaperSheet<void>(
      context,
      child: _TermSheet(
        note: note,
        onSeeAll: () {
          Navigator.of(context).pop();
          unawaited(context.push(AppRoutes.notes(kind: 'term')));
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const EyebrowText('相關術語'),
      const SizedBox(height: AppSpace.s2),
      RuledList(
        children: [
          for (final note in _termNotes)
            RuledTile(
              title: MixedText(note.term),
              onTap: () => _open(context, note),
            ),
        ],
      ),
    ],
  );
}

class _TermSheet extends StatelessWidget {
  const _TermSheet({required this.note, required this.onSeeAll});

  final NoteDto_Term note;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      NoteBody(note: note),
      const SizedBox(height: AppSpace.s5),
      GhostButton(label: '看全部術語', onPressed: onSeeAll),
    ],
  );
}
