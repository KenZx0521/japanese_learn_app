import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/error_slip.dart';
import '../../design/widgets/note_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/skeleton_lines.dart';

final noteListProvider = FutureProvider.autoDispose
    .family<List<NoteDto>, NoteKind>(
      (ref, kind) => ref.watch(noteRepositoryProvider).list(kind),
    );

/// 分頁順序與 `?kind=` 的值（§3.11）。
const _tabs = <(NoteKind, String, String)>[
  (NoteKind.falseFriend, 'false_friend', '同形異義'),
  (NoteKind.shinjitai, 'shinjitai', '字形對照'),
  (NoteKind.reading, 'reading', '讀音規律'),
  (NoteKind.transfer, 'transfer', '語言轉移'),
  (NoteKind.term, 'term', '術語'),
];

NoteKind _kindFromQuery(String? query) {
  for (final (kind, value, _) in _tabs) {
    if (value == query) return kind;
  }
  return NoteKind.falseFriend;
}

String _noteId(NoteDto note) => switch (note) {
  NoteDto_FalseFriend(:final id) ||
  NoteDto_Shinjitai(:final id) ||
  NoteDto_Reading(:final id) ||
  NoteDto_Transfer(:final id) ||
  NoteDto_Term(:final id) => id,
};

/// N1 漢字陷阱（§3.11）。
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({this.kind, super.key});

  final String? kind;

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  late NoteKind _kind = _kindFromQuery(widget.kind);

  @override
  void didUpdateWidget(NotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) _kind = _kindFromQuery(widget.kind);
  }

  void _select(NoteKind kind, String query) {
    if (kind == _kind) return;
    setState(() => _kind = kind);
    GoRouter.maybeOf(context)?.replace(AppRoutes.notes(kind: query));
  }

  @override
  Widget build(BuildContext context) => PaperScaffold(
    scrollable: false,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: PageBackLink(fallback: AppRoutes.learn),
        ),
        const AppText('漢字陷阱', scale: TypeScale.displayM),
        const SizedBox(height: AppSpace.s3),
        _TabStrip(current: _kind, onSelect: _select),
        const SizedBox(height: AppSpace.s4),
        Expanded(child: _NoteList(kind: _kind)),
      ],
    ),
  );
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.current, required this.onSelect});

  final NoteKind current;
  final void Function(NoteKind kind, String query) onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line.grid)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (kind, query, label) in _tabs)
              _Tab(
                label: label,
                selected: kind == current,
                onTap: () => onSelect(kind, query),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  @override
  void initState() {
    super.initState();
    if (widget.selected) _revealAfterLayout();
  }

  @override
  void didUpdateWidget(_Tab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) _revealAfterLayout();
  }

  /// 五個分頁在手機上放不下：`?kind=` 進來或點到半露的分頁時要捲到看得見。
  void _revealAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final motion = AppMotion.of(context).base;
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: motion.duration,
          curve: motion.curve,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final motion = AppMotion.of(context).fast;
    return Pressable(
      onTap: widget.onTap,
      selected: widget.selected,
      builder: (context, state) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              constraints: const BoxConstraints(
                minHeight: PaperLayout.minTarget,
              ),
              alignment: Alignment.center,
              child: AppText(
                widget.label,
                scale: TypeScale.label,
                color: widget.selected || state.hovered
                    ? t.ink.primary
                    : t.ink.secondary,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: widget.selected ? 1 : 0,
                duration: motion.duration,
                curve: motion.curve,
                child: Container(height: 2, color: t.shu),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteList extends ConsumerWidget {
  const _NoteList({required this.kind});

  final NoteKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = noteListProvider(kind);
    return ref
        .watch(provider)
        .when(
          data: (notes) => _NotesView(notes: notes),
          loading: () => const DelayedReveal(child: SkeletonLines()),
          error: (error, _) => ErrorSlip.fromObject(
            error,
            onRetry: () => ref.invalidate(provider),
          ),
        );
  }
}

class _NotesView extends StatelessWidget {
  const _NotesView({required this.notes});

  final List<NoteDto> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const AppText('這一版還沒有這類筆記');
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _NoteTile(key: ValueKey(_noteId(note)), note: note);
      },
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note, super.key});

  final NoteDto note;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line.grid)),
      ),
      child: NoteBody(
        note: note,
        onOpenVocab: (id) => context.push(AppRoutes.vocabWord(id)),
        onOpenGrammar: (id) => context.push(AppRoutes.grammarPoint(id)),
      ),
    );
  }
}
