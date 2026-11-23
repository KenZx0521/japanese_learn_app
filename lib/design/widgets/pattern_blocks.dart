import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../core/text/ja_text.dart';
import '../tokens.dart';
import 'app_text.dart';

/// 文法公式（§3.5）：日文段是實心塊，中文段（N、V）是空框。
class PatternBlocks extends ConsumerWidget {
  const PatternBlocks(this.pattern, {super.key});
  final String pattern;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final spans = ref.watch(textToolsProvider).parseMixedText(pattern);
    final children = <Widget>[];
    for (final span in spans) {
      switch (span) {
        case MixedSpanDto_Ja(:final text):
          children.add(_JaBlock(text: text));
        case MixedSpanDto_Zh(:final text):
          children.addAll(
            text
                .trim()
                .split(RegExp(r'\s+'))
                .where((p) => p.isNotEmpty)
                .map((part) => _SlotFrame(text: part)),
          );
      }
    }
    return Semantics(
      container: true,
      label: pattern.replaceAll(RegExp(r'\{ja:|\|[^}]*|\}'), ''),
      child: ExcludeSemantics(
        child: Wrap(
          spacing: AppSpace.s1,
          runSpacing: AppSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final child in children)
              DefaultTextStyle.merge(
                style: TextStyle(color: t.ink.primary),
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}

class _JaBlock extends StatelessWidget {
  const _JaBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s1,
      ),
      color: t.ink.primary,
      child: JaText(text, color: t.paper.base),
    );
  }
}

class _SlotFrame extends StatelessWidget {
  const _SlotFrame({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s1,
      ),
      decoration: BoxDecoration(border: Border.all(color: t.line.strong)),
      child: AppText(text, scale: TypeScale.label, color: t.ink.secondary),
    );
  }
}
