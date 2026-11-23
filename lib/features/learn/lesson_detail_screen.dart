import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/display_context.dart';
import '../../design/tokens.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/refresh_on_return.dart';
import 'learn_providers.dart';
import 'lesson_detail_body.dart';
import 'lesson_detail_sections.dart';

/// L2 課程詳情（§2.3）：本課 can-do、新字、文法、規則卡、對話，各項可點進去。
class LessonDetailScreen extends ConsumerWidget {
  const LessonDetailScreen({required this.lessonId, super.key});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = lessonDetailProvider(lessonId);
    final lesson = ref.watch(provider);
    final policy = ref
        .watch(displayPolicyProvider(DisplayContext(lessonId: lessonId)))
        .value;
    void refresh() => ref.invalidate(provider);
    return RefreshOnReturn(
      onReturn: refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= PaperLayout.wideBreakpoint;
          final detail = lesson.value;
          return PaperScaffold(
            aside: wide && detail != null
                ? LessonDetailSections.aside(detail: detail)
                : null,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageBackLink(fallback: AppRoutes.learn),
                const SizedBox(height: AppSpace.s2),
                AsyncBody<LessonDetailDto>(
                  value: lesson,
                  onRetry: refresh,
                  data: (data) => LessonDetailBody(
                    detail: data,
                    wide: wide,
                    romajiMode: policy?.romaji,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
