import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

/// 振假名懸掛（ルビの掛け，取 JIS X 4051 的精神）的純計算，`RubyBox` 用。
///
/// ruby 比底字寬時，可以懸在相鄰、本身沒有 ruby 的假名、標點或中文上方，
/// 每側至多一個 ruby 字寬；段的版面寬度 = max(底字寬, ruby 寬 − 兩側允許懸掛)，
/// 比底字多出來的寬度依 1:2:1 分配到底字之間與兩端。

/// 一段 ruby 旁邊、本身沒有 ruby 的文字（含詞距）。
@immutable
final class RubyRun {
  const RubyRun({required this.width, this.shared = false, this.farExcess});

  /// 沒有相鄰文字（段首、段尾）。
  static const none = RubyRun(width: 0);

  /// 量得的寬度；可以只量靠近這段的幾個字（下界即可，結果只會更保守）。
  final double width;

  /// 這段文字的另一頭還有 ruby，兩段 ruby 要分用它。
  final bool shared;

  /// 另一頭那段 ruby 比它的底字寬多少（它往這邊懸出的上限）；null 表示不知道。
  final double? farExcess;

  /// 本段兩側合計可以懸出多少，另一頭的 ruby 才不會被擠到重疊。
  /// 各分一半一定安全；另一頭懸不了多少時，剩下的都可以給本段。
  double get budget {
    final half = math.max(0.0, width / 2);
    final excess = farExcess;
    return excess == null ? half : math.max(half, width - excess);
  }
}

/// ruby 每側最多可以懸出底字多少。
@immutable
final class RubyOverhang {
  const RubyOverhang({required this.start, required this.end});

  static const none = RubyOverhang(start: 0, end: 0);

  final double start, end;

  /// 每側至多一個 ruby 字寬（[rubyEm]：ruby 寬 ÷ 字數），也不超過相鄰文字本身。
  ///
  /// 相鄰文字另一頭也有 ruby 時，本段兩側合計不超過 [RubyRun.budget]：
  /// 行首、行尾把 ruby 推回容器內時，另一側最多多懸出這個合計量，
  /// 兩段 ruby 分用同一段文字仍不會重疊。
  factory RubyOverhang.resolve({
    required double rubyEm,
    required RubyRun start,
    required RubyRun end,
  }) {
    double own(RubyRun run) =>
        math.max(0, math.min(rubyEm, run.shared ? run.budget : run.width));
    final cap = [
      for (final run in [start, end])
        if (run.shared) run.budget,
    ].fold(double.infinity, math.min);
    final ownStart = own(start);
    final ownEnd = own(end);
    final resolvedStart = math.min(ownStart, math.max(cap / 2, cap - ownEnd));
    return RubyOverhang(
      start: resolvedStart,
      end: math.min(ownEnd, cap - resolvedStart),
    );
  }
}

/// 一段的版面：寬度、底字的字距、ruby 在段內的左緣（可為負，表示往前懸）。
@immutable
final class RubyFit {
  const RubyFit({
    required this.width,
    required this.baseSpacing,
    required this.rubyLeft,
  });

  final double width;

  /// 底字的字距（JIS X 4051 的 1:2:1）。文字引擎把字距前後各半加在每個字兩側，
  /// 所以底字從段首排起，字間是一份、兩端各半份；單一底字就是置中。
  final double baseSpacing;
  final double rubyLeft;

  /// 懸掛額度用完後還有剩的寬度，平均成 [baseSpacing]。[baseLength] 是底字字數。
  factory RubyFit.compute({
    required double base,
    required double ruby,
    required int baseLength,
    required RubyOverhang overhang,
    double maxWidth = double.infinity,
  }) {
    final start = overhang.start;
    final end = overhang.end;
    final width = math.min(
      math.max(base, ruby - start - end),
      math.max(base, maxWidth),
    );
    final low = -start;
    final high = width + end - ruby;
    final centered = (width - ruby) / 2;
    return RubyFit(
      width: width,
      baseSpacing: baseLength > 0 ? (width - base) / baseLength : 0,
      // 比 maxWidth 還寬的 ruby 無法守住允許量，只能置中
      rubyLeft: low <= high ? centered.clamp(low, high) : centered,
    );
  }
}
