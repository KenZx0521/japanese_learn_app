import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';

final kanaChartProvider = FutureProvider.autoDispose
    .family<List<KanaGroupDto>, KanaScript>(
      (ref, script) => ref.watch(kanaRepositoryProvider).chart(script),
    );

final kanaDetailProvider = FutureProvider.autoDispose
    .family<KanaDetailDto, String>(
      (ref, id) => ref.watch(kanaRepositoryProvider).detail(id),
    );

/// `kana_chart` 的格子是否全部尚未開始（K1 的空狀態，§2.3）。
bool isChartUntouched(List<KanaGroupDto> groups) => groups.every(
  (group) => group.rows.every(
    (row) => row.cells.every(
      (cell) => cell == null || cell.status == KanaStatus.notStarted,
    ),
  ),
);
