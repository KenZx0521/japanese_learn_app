import 'package:material_ui/material_ui.dart' show immutable;

/// 排序題目前放上答題線的詞塊，存 `ChunkDto.index`。
@immutable
final class ReorderDraft {
  const ReorderDraft([this.placed = const []]);

  final List<int> placed;

  bool isPlaced(int chunkIndex) => placed.contains(chunkIndex);

  bool isComplete(int chunkCount) => placed.length == chunkCount;

  /// 點一下放上去，再點移回（§3.6）。
  ReorderDraft toggle(int chunkIndex) => ReorderDraft(
    isPlaced(chunkIndex)
        ? [
            for (final index in placed)
              if (index != chunkIndex) index,
          ]
        : [...placed, chunkIndex],
  );
}
