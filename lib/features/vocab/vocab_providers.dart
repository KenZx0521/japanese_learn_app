import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/failures.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../core/backend/today_view_provider.dart';

/// 搜尋與列表每次取的筆數（§3.4）。
const vocabPageSize = 50;

final vocabTopicsProvider = FutureProvider.autoDispose<List<TopicDto>>(
  (ref) => ref.watch(vocabRepositoryProvider).topics(),
);

final vocabSearchProvider = FutureProvider.autoDispose
    .family<List<VocabSummaryDto>, String>(
      (ref, query) =>
          ref.watch(vocabRepositoryProvider).search(query, vocabPageSize),
    );

typedef VocabDetailView = ({VocabDetailDto detail, DisplayPolicyDto policy});

/// 詳情與顯示規則一起取，重試時兩個都重來（§3.7：依單字所屬的課）。
final vocabDetailViewProvider = FutureProvider.autoDispose
    .family<VocabDetailView, String>((ref, id) async {
      final vocab = ref.watch(vocabRepositoryProvider);
      final settings = ref.watch(settingsRepositoryProvider);
      final detail = await vocab.detail(id);
      final policy = await settings.displayPolicy(
        DisplayContext(lessonId: detail.summary.lessonId),
      );
      return (detail: detail, policy: policy);
    });

/// 讀不到時 V3 不顯示級別標籤（寧可少標，不可超出 O7 範圍）。
final vocabContentStageProvider = FutureProvider.autoDispose<ContentStage>(
  (ref) async =>
      (await ref.watch(courseRepositoryProvider).overview()).contentStage,
);

/// V3 改過的旗標，讓還留在堆疊裡的 V1、V2 列表不必重新分頁也能更新。
final vocabFlagOverridesProvider =
    NotifierProvider.autoDispose<
      VocabFlagOverrides,
      Map<String, VocabFlagsDto>
    >(VocabFlagOverrides.new);

class VocabFlagOverrides extends Notifier<Map<String, VocabFlagsDto>> {
  @override
  Map<String, VocabFlagsDto> build() => const {};

  void record(String id, VocabFlagsDto flags) => state = {...state, id: flags};
}

/// 列表與詳情都用這個取目前的旗標。
VocabFlagsDto vocabFlagsOf(WidgetRef ref, VocabSummaryDto word) =>
    ref.watch(
      vocabFlagOverridesProvider.select((overrides) => overrides[word.id]),
    ) ??
    VocabFlagsDto(known: word.known, starred: word.starred);

@immutable
final class VocabFlagState {
  const VocabFlagState({this.saving = false, this.failure, this.attempt});

  final bool saving;
  final AppFailure? failure;

  /// 失敗時留著，重試送同一份。
  final VocabFlagsDto? attempt;
}

final vocabFlagControllerProvider = NotifierProvider.autoDispose
    .family<VocabFlagController, VocabFlagState, String>(
      VocabFlagController.new,
    );

class VocabFlagController extends Notifier<VocabFlagState> {
  VocabFlagController(this.vocabId);

  final String vocabId;

  @override
  VocabFlagState build() => const VocabFlagState();

  Future<void> save(VocabFlagsDto flags) async {
    if (state.saving) return;
    state = VocabFlagState(saving: true, attempt: flags);
    try {
      final saved = await ref
          .read(vocabRepositoryProvider)
          .setFlags(vocabId, flags);
      if (!ref.mounted) return;
      ref
          .read(vocabFlagOverridesProvider.notifier)
          .record(
            vocabId,
            VocabFlagsDto(known: saved.known, starred: saved.starred),
          );
      // 「已會」會把卡片移出複習，今日的張數要重新算
      ref.invalidate(todayViewProvider);
      state = const VocabFlagState();
    } on AppFailure catch (failure) {
      if (ref.mounted) {
        state = VocabFlagState(failure: failure, attempt: flags);
      }
    }
  }

  Future<void> retry() async {
    final attempt = state.attempt;
    if (attempt != null) await save(attempt);
  }
}
