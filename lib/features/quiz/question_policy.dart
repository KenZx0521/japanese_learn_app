import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/failures.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/local_log.dart';
import '../../core/backend/providers.dart';
import '../../core/text/display_context.dart';

/// 零基礎者最安全的預設：全顯示。`ka.*` 不套用規則，也用這份。
const fallbackQuestionPolicy = DisplayPolicyDto(
  romaji: RomajiMode.shown,
  furigana: FuriganaMode.all,
  wordSpacing: true,
);

/// 題目的顯示規則（§3.7）。參數的第二項是呼叫端已知的 `fallbackLessonId`。
final questionPolicyProvider = FutureProvider.autoDispose
    .family<DisplayPolicyDto, (QuestionRefDto, String?)>((ref, key) async {
      final (reference, knownFallback) = key;
      if (reference.contentId.startsWith('ka.')) return fallbackQuestionPolicy;
      final peeked = await _peekOf(ref, reference.contentId);
      final fallback = peeked?.lessonId == null
          ? knownFallback ?? await _resolveFallbackLesson(ref)
          : '';
      try {
        return await ref.watch(
          displayPolicyProvider(questionContext(peeked, fallback)).future,
        );
      } on AppFailure catch (failure, stack) {
        // 顯示規則讀不到不該擋作答，退回全顯示
        logLocal(failure, stack);
        return fallbackQuestionPolicy;
      }
    });

/// `peek` 失敗不擋作答，退回 fallback 的課。`se.*` 不呼叫 `peek`（§3.7）。
Future<PeekDto?> _peekOf(Ref ref, String contentId) async {
  if (contentId.startsWith('se.')) return null;
  try {
    return await ref.watch(peekProvider(contentId).future);
  } on AppFailure catch (failure, stack) {
    logLocal(failure, stack);
    return null;
  }
}

/// §3.7：`PlanViewDto.current_lesson_id`，游標走完時用最後一個 L 課。
Future<String> _resolveFallbackLesson(Ref ref) async {
  try {
    final current =
        (await ref.read(planRepositoryProvider).view()).currentLessonId;
    if (current != null) return current;
    final overview = await ref.read(courseRepositoryProvider).overview();
    final mainLessons = overview.lessons.where(
      (lesson) => lesson.id.startsWith('le.l'),
    );
    return mainLessons.lastOrNull?.id ?? '';
  } on AppFailure catch (failure, stack) {
    logLocal(failure, stack);
    return '';
  }
}
