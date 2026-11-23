import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/error_slip.dart';
import '../vocab_providers.dart';
import 'toggle_tag.dart';

/// V3 右上的「已會」「收藏」（§3.4）。
class VocabFlagButtons extends ConsumerWidget {
  const VocabFlagButtons({required this.word, super.key});

  final VocabSummaryDto word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = vocabFlagControllerProvider(word.id);
    final saving = ref.watch(provider.select((state) => state.saving));
    final flags = vocabFlagsOf(ref, word);
    void save(VocabFlagsDto next) =>
        unawaited(ref.read(provider.notifier).save(next));
    return Wrap(
      spacing: AppSpace.s2,
      runSpacing: AppSpace.s2,
      children: [
        ToggleTag(
          label: '已會',
          value: flags.known,
          onChanged: saving
              ? null
              : (known) =>
                    save(VocabFlagsDto(known: known, starred: flags.starred)),
        ),
        ToggleTag(
          label: '收藏',
          value: flags.starred,
          onChanged: saving
              ? null
              : (starred) =>
                    save(VocabFlagsDto(known: flags.known, starred: starred)),
        ),
      ],
    );
  }
}

/// 標記鈕的說明與失敗訊息，放在標題區下方。
class VocabFlagFeedback extends ConsumerWidget {
  const VocabFlagFeedback({required this.word, super.key});

  final VocabSummaryDto word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = vocabFlagControllerProvider(word.id);
    final failure = ref.watch(provider.select((state) => state.failure));
    final known = vocabFlagsOf(ref, word).known;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (known)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s2),
            child: AppText(
              '這個字之後不會出現在複習裡。',
              scale: TypeScale.caption,
              color: AppTokens.of(context).ink.secondary,
            ),
          ),
        if (failure != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s3),
            child: ErrorSlip(
              failure: failure,
              onRetry: () => unawaited(ref.read(provider.notifier).retry()),
            ),
          ),
      ],
    );
  }
}
