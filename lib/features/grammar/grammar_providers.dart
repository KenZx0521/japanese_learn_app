import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/course_groups.dart';
import '../../core/backend/drill_questions_provider.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';

/// G1：依階段分組的文法點。參數是已去空白的搜尋字，null 表示不搜尋。
final grammarListProvider = FutureProvider.autoDispose
    .family<List<StageGroup<GrammarSummaryDto>>, String?>((ref, query) async {
      final grammar = ref.watch(grammarRepositoryProvider);
      final course = ref.watch(courseRepositoryProvider);
      // 依序等待：並行失敗會包成 ParallelWaitError，訊息變成未預期錯誤
      final overview = await course.overview();
      final items = await grammar.list(query: query);
      return groupByStage(items, overview.stages, (item) => item.stageId);
    });

final grammarDetailProvider = FutureProvider.autoDispose
    .family<GrammarDetailDto, String>(
      (ref, id) => ref.watch(grammarRepositoryProvider).detail(id),
    );

/// G2 小測驗的題數（§3.5）。
const grammarQuizCount = 3;

DrillQuery grammarQuizQuery(String grammarId) =>
    (lessonId: null, target: grammarId, drillIds: '', count: grammarQuizCount);
