import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// 量相鄰文字時最多取幾個字。只拿來算懸掛的上限，下界就夠（ruby_fit.dart）。
const _runChars = 8;

/// 排成一行的一小段：中文、沒有 ruby 的日文、或帶 ruby 的一段。
@immutable
final class RubyPiece {
  const RubyPiece(
    this.span, {
    this.hasRuby = false,
    this.ruby,
    this.gapBefore = 0,
  });

  /// 這段的文字與樣式（量寬度用，不顯示）。
  final TextSpan span;
  final bool hasRuby;

  /// 讀音的文字與樣式；null 表示不知道（例如空格），鄰居只能平分。
  final TextSpan? ruby;

  /// 和前一段之間、不在文字裡的空白（`RubyLine` 的分詞空格）。
  final double gapBefore;
}

/// 一段 ruby 某一側相鄰、本身沒有 ruby 的文字。null 表示那一側什麼都沒有。
@immutable
final class RubyNeighbor {
  const RubyNeighbor({
    required this.text,
    this.gap = 0,
    this.shared = false,
    this.far,
  });

  final TextSpan text;

  /// 文字以外的空白寬度，加在量得的文字寬度上。
  final double gap;

  /// 這段文字的另一頭還有 ruby。
  final bool shared;

  /// 另一頭那段 ruby 的底字與讀音，量出它最多往這邊懸多少。
  final ({TextSpan base, TextSpan ruby})? far;

  @override
  bool operator ==(Object other) =>
      other is RubyNeighbor &&
      other.text == text &&
      other.gap == gap &&
      other.shared == shared &&
      other.far == far;

  @override
  int get hashCode => Object.hash(text, gap, shared, far);
}

typedef RubyEdges = ({RubyNeighbor? start, RubyNeighbor? end});

/// 不懸掛（沒有 ruby 的段）。
const RubyEdges noRubyEdges = (start: null, end: null);

/// `pieces[index]` 前後相鄰、沒有 ruby 的文字。
/// [startSkip]、[endSkip]：緊接在前、在後，已經放進同一個盒子的段數
/// （例如開括號、收尾標點）。
RubyEdges rubyEdgesOf(
  List<RubyPiece> pieces,
  int index, {
  int startSkip = 0,
  int endSkip = 0,
}) => (
  start: _scan(pieces, index - startSkip, step: -1),
  end: _scan(pieces, index + endSkip, step: 1),
);

RubyNeighbor? _scan(List<RubyPiece> pieces, int from, {required int step}) {
  final texts = <TextSpan>[];
  var gap = 0.0;
  var budget = _runChars;
  var inner = from;
  for (var i = from + step; i >= 0 && i < pieces.length; i += step) {
    gap += pieces[step > 0 ? i : inner].gapBefore;
    final piece = pieces[i];
    if (piece.hasRuby) {
      final ruby = piece.ruby;
      return RubyNeighbor(
        text: _join(texts, step),
        gap: gap,
        shared: true,
        far: ruby == null ? null : (base: piece.span, ruby: ruby),
      );
    }
    final clipped = _clip(piece.span, budget, fromEnd: step < 0);
    texts.add(clipped);
    budget -= (clipped.text ?? '').runes.length;
    inner = i;
  }
  if (texts.isEmpty) return null;
  return RubyNeighbor(text: _join(texts, step), gap: gap);
}

/// 只留靠近 ruby 的 [budget] 個字。
TextSpan _clip(TextSpan span, int budget, {required bool fromEnd}) {
  final runes = (span.text ?? '').runes.toList();
  final keep = budget.clamp(0, runes.length);
  final kept = fromEnd
      ? runes.sublist(runes.length - keep)
      : runes.sublist(0, keep);
  return TextSpan(text: String.fromCharCodes(kept), style: span.style);
}

TextSpan _join(List<TextSpan> texts, int step) =>
    TextSpan(children: step < 0 ? texts.reversed.toList() : texts);
