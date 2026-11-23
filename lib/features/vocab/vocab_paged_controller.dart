import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/failures.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import 'vocab_providers.dart';

@immutable
final class VocabPagedData {
  const VocabPagedData({
    required this.items,
    required this.total,
    this.loadingMore = false,
    this.moreFailure,
  });

  final List<VocabSummaryDto> items;
  final int total;
  final bool loadingMore;

  /// 下一頁失敗時留在清單尾端顯示，已載入的列不受影響。
  final AppFailure? moreFailure;

  bool get hasMore => items.length < total;

  VocabPagedData copyWith({
    List<VocabSummaryDto>? items,
    int? total,
    bool? loadingMore,
    AppFailure? moreFailure,
    bool clearFailure = false,
  }) => VocabPagedData(
    items: items ?? this.items,
    total: total ?? this.total,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailure: clearFailure ? null : moreFailure ?? this.moreFailure,
  );
}

final vocabPagedProvider = AsyncNotifierProvider.autoDispose
    .family<VocabPagedController, VocabPagedData, VocabFilterDto>(
      VocabPagedController.new,
    );

/// V2 的分頁（§3.4）。`VocabFilterDto` 沒有 Vec，可當 family 參數。
class VocabPagedController extends AsyncNotifier<VocabPagedData> {
  VocabPagedController(this.filter);

  final VocabFilterDto filter;

  @override
  Future<VocabPagedData> build() async {
    final page = await ref
        .watch(vocabRepositoryProvider)
        .page(filter, 0, vocabPageSize);
    return VocabPagedData(items: page.items, total: page.total);
  }

  /// 捲近底部時呼叫。上一次失敗後等使用者按重試，不自動重送。
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.loadingMore ||
        !current.hasMore ||
        current.moreFailure != null) {
      return;
    }
    await _fetchNext(current);
  }

  Future<void> retryMore() async {
    final current = state.value;
    if (current == null || current.loadingMore) return;
    await _fetchNext(current.copyWith(clearFailure: true));
  }

  Future<void> _fetchNext(VocabPagedData current) async {
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(vocabRepositoryProvider)
          .page(filter, current.items.length, vocabPageSize);
      if (!ref.mounted) return;
      final items = [...current.items, ...page.items];
      state = AsyncData(
        current.copyWith(
          items: items,
          // 回傳空頁時視為已到底，避免捲動時無止盡重取
          total: page.items.isEmpty ? items.length : page.total,
          loadingMore: false,
        ),
      );
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, moreFailure: failure),
      );
    }
  }
}
