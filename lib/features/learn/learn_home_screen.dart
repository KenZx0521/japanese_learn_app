import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/refresh_on_return.dart';
import '../../design/widgets/vertical_title.dart';
import 'learn_course_list.dart';
import 'learn_current_block.dart';
import 'learn_library.dart';
import 'learn_providers.dart';

/// L1 學習首頁（§2.3）：目前位置、資料庫入口、依階段分組的課程。
class LearnHomeScreen extends ConsumerWidget {
  const LearnHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(learnCourseProvider);
    void refresh() => ref.invalidate(learnCourseProvider);
    return RefreshOnReturn(
      onReturn: refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= PaperLayout.wideBreakpoint;
          return PaperScaffold(
            aside: wide
                ? LearnLibrary(
                    notesAvailable: course.value?.notesAvailable ?? false,
                    vertical: true,
                  )
                : null,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Heading(stage: course.value?.contentStage),
                const SizedBox(height: AppSpace.s5),
                AsyncBody<CourseOverviewDto>(
                  value: course,
                  onRetry: refresh,
                  data: (overview) =>
                      _Content(overview: overview, showLibrary: !wide),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.stage});

  final ContentStage? stage;

  /// O7：只有 `p0a` 有固定的範圍說法，其餘版本不在這裡宣稱範圍。
  String? get _scope => stage == ContentStage.p0A ? '這一版有假名與入門七課' : null;

  @override
  Widget build(BuildContext context) {
    final scope = _scope;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('學習', scale: TypeScale.displayM),
              if (scope != null) ...[
                const SizedBox(height: AppSpace.s1),
                AppText(scope, color: AppTokens.of(context).ink.secondary),
              ],
            ],
          ),
        ),
        const VerticalTitle('学'),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.overview, required this.showLibrary});

  final CourseOverviewDto overview;
  final bool showLibrary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LearnCurrentBlock(overview: overview),
      if (showLibrary) ...[
        const SizedBox(height: AppSpace.s6),
        LearnLibrary(notesAvailable: overview.notesAvailable),
      ],
      if (overview.lessons.isNotEmpty) ...[
        const SizedBox(height: AppSpace.s6),
        LearnCourseList(overview: overview),
      ],
    ],
  );
}
