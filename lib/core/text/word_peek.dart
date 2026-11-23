import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/sheet_frame.dart';
import '../backend/frb/dto.dart';
import 'display_context.dart';
import 'ja_text.dart';
import 'mixed_text.dart';

/// `RubyLine.onWordTap` 的預設行為：開 `WordPeek` 底部面板（§3.7）。
Future<void> showWordPeek(
  BuildContext context,
  WordDto word, {
  ValueChanged<String>? onOpenDetail,
}) => showPaperSheet<void>(
  context,
  child: WordPeek(word: word, onOpenDetail: onOpenDetail),
);

class WordPeek extends ConsumerWidget {
  const WordPeek({required this.word, this.onOpenDetail, super.key});

  final WordDto word;
  final ValueChanged<String>? onOpenDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refId = word.refId;
    if (refId == null) return _GlossOnly(word: word);
    final peek = ref.watch(peekProvider(refId));
    return AsyncBody<PeekDto>(
      value: peek,
      onRetry: () => ref.invalidate(peekProvider(refId)),
      data: (data) => _PeekContent(peek: data, onOpenDetail: onOpenDetail),
    );
  }
}

class _GlossOnly extends StatelessWidget {
  const _GlossOnly({required this.word});
  final WordDto word;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      JaText(word.surface, scale: TypeScale.jaSentence),
      const SizedBox(height: AppSpace.s2),
      AppText(word.glossZh ?? '這個詞還沒有說明。'),
    ],
  );
}

class _PeekContent extends StatelessWidget {
  const _PeekContent({required this.peek, this.onOpenDetail});
  final PeekDto peek;
  final ValueChanged<String>? onOpenDetail;

  bool get _titleIsJapanese =>
      peek.refId.startsWith('vo.') || peek.refId.startsWith('ka.');

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final open = onOpenDetail;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_titleIsJapanese)
          JaText(peek.title, scale: TypeScale.jaSentence)
        else
          MixedText(peek.title, scale: TypeScale.title),
        if (peek.kana != null) ...[
          const SizedBox(height: AppSpace.s1),
          JaText(peek.kana!, color: t.ink.secondary),
        ],
        if (peek.romaji != null)
          AppText(
            peek.romaji!,
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
        const SizedBox(height: AppSpace.s3),
        MixedText(peek.summaryZh),
        if (open != null) ...[
          const SizedBox(height: AppSpace.s4),
          GhostButton(label: '看完整內容', onPressed: () => open(peek.refId)),
        ],
      ],
    );
  }
}
