import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/display_context.dart';
import '../../core/text/romaji_scope.dart';
import '../../core/text/romaji_toggle.dart';
import '../../design/tokens.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import 'grammar_article.dart';
import 'grammar_providers.dart';

/// G2 文法點（§3.5）：一頁短文章，頁尾內嵌小測驗。
class GrammarDetailScreen extends ConsumerWidget {
  const GrammarDetailScreen({required this.grammarId, super.key});

  final String grammarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = grammarDetailProvider(grammarId);
    final value = ref.watch(provider);
    final lessonId = value.value?.summary.lessonId;
    return RomajiPageScope(
      child: PaperScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: PageBackLink(fallback: AppRoutes.grammar())),
                if (lessonId != null) _PageRomajiToggle(lessonId: lessonId),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            AsyncBody<GrammarDetailDto>(
              value: value,
              onRetry: () => ref.invalidate(provider),
              data: (detail) => GrammarArticle(detail: detail),
            ),
          ],
        ),
      ),
    );
  }
}

/// 只有 `ShownToggleable` 才有開關（§3.7）。放在返回列，載入後版面不跳動。
class _PageRomajiToggle extends ConsumerWidget {
  const _PageRomajiToggle({required this.lessonId});
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = DisplayContext(lessonId: lessonId);
    final policy = ref.watch(displayPolicyProvider(display)).value;
    return policy?.romaji == RomajiMode.shownToggleable
        ? const RomajiToggle()
        : const SizedBox.shrink();
  }
}
