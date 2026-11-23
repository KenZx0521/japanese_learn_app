import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tts/audio_available.dart';
import 'frb/dto.dart';
import 'providers.dart';
import 'today_view_provider.dart';

/// `drill_session` 的條件。`DrillFilterDto` 含 Vec 不能當 family 參數，
/// 改用基本型別，`drillIds` 以逗號分隔（architecture §5.2）。
typedef DrillQuery = ({
  String? lessonId,
  String? target,
  String drillIds,
  int count,
});

DrillFilterDto _filterOf(DrillQuery query) => DrillFilterDto(
  lessonId: query.lessonId,
  target: query.target,
  drillIds: query.drillIds.isEmpty ? const [] : query.drillIds.split(','),
  count: query.count,
);

/// D2、G2 小測驗的題目。同一邏輯日 seed 相同，離開再進來題目不變（§5.2）。
///
/// 語音探測完成前停在載入階段（§6.6）。只選 `logicalDate`，回到前景更新今日資料時
/// 不會重取，否則 FRB 回傳的新物件會讓進行中的回合重置。
final drillQuestionsProvider = FutureProvider.autoDispose
    .family<List<QuestionDto>, DrillQuery>((ref, query) async {
      if (!ref.watch(audioResolvedProvider)) {
        return Completer<List<QuestionDto>>().future;
      }
      final audio = ref.watch(audioAvailableProvider);
      final drills = ref.watch(drillRepositoryProvider);
      final date = await ref.watch(
        todayViewProvider.selectAsync((today) => today.logicalDate),
      );
      return drills.session(_filterOf(query), sessionSeed(date), audio);
    });

/// 失敗可能來自今日資料，兩者都要重取。
void retryDrillQuestions(WidgetRef ref, DrillQuery query) {
  ref.invalidate(todayViewProvider);
  ref.invalidate(drillQuestionsProvider(query));
}
