import 'dart:math';

import 'package:material_ui/material_ui.dart' show immutable;

import '../../../core/backend/frb/dto.dart';

/// 配對題的盤面（§3.3）。`Match` 是唯一由 Dart 判定的題型（rust-core §8.4）。
@immutable
final class MatchBoard {
  const MatchBoard({
    required this.pairs,
    required this.rightOrder,
    this.selectedLeft,
    this.matched = const {},
    this.wrongRight,
    this.mistakes = 0,
  });

  /// Rust 的 `pairs` 左右對齊，只洗過整對，右欄要自己重排，否則一眼看出答案。
  factory MatchBoard.start(List<MatchPairDto> pairs, {required int seed}) =>
      MatchBoard(pairs: pairs, rightOrder: _shuffledRight(pairs.length, seed));

  final List<MatchPairDto> pairs;

  /// 右欄由上到下對應的 `pairs` 索引。
  final List<int> rightOrder;
  final int? selectedLeft;
  final Set<int> matched;
  final int? wrongRight;
  final int mistakes;

  bool isMatched(int pairIndex) => matched.contains(pairIndex);

  bool get isComplete => matched.length == pairs.length;

  bool get allCorrect => mistakes == 0;

  MatchBoard tapLeft(int pairIndex) {
    if (isMatched(pairIndex)) return this;
    return _copy(selectedLeft: pairIndex, matched: matched, mistakes: mistakes);
  }

  MatchBoard tapRight(int pairIndex) {
    final left = selectedLeft;
    if (left == null || isMatched(pairIndex)) return this;
    if (pairs[left].rightId == pairs[pairIndex].rightId) {
      return _copy(matched: {...matched, left}, mistakes: mistakes);
    }
    return _copy(
      matched: matched,
      mistakes: mistakes + 1,
      wrongRight: pairIndex,
    );
  }

  MatchBoard _copy({
    required Set<int> matched,
    required int mistakes,
    int? selectedLeft,
    int? wrongRight,
  }) => MatchBoard(
    pairs: pairs,
    rightOrder: rightOrder,
    selectedLeft: selectedLeft,
    matched: matched,
    wrongRight: wrongRight,
    mistakes: mistakes,
  );

  static List<int> _shuffledRight(int count, int seed) {
    final order = List<int>.generate(count, (i) => i)..shuffle(Random(seed));
    final aligned = [for (var i = 0; i < count; i++) order[i] == i]
        .every((e) => e);
    if (count > 1 && aligned) {
      return [...order.skip(1), order.first];
    }
    return order;
  }
}
