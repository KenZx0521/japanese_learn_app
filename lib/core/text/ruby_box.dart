import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import 'ruby_fit.dart';
import 'ruby_kinsoku.dart';
import 'ruby_neighbor.dart';

/// 判定 ruby 超出容器的容差。
const _edgeEpsilon = 0.01;

enum RubySlot { leading, base, ruby, trailing }

/// 沒有讀音的底字。比一行還長時會在字中間換行，所以守住禁則；報讀與比對仍是原文。
/// 有讀音的底字不經過這裡：它的字距以字數計算，不能多出零寬字。
Text plainRubyBaseText(
  String data, {
  required TextStyle style,
  required TextScaler textScaler,
}) {
  final joined = withLineStartJoiners(data);
  return joined == data
      ? Text(data, locale: jaLocale, style: style, textScaler: textScaler)
      : Text.rich(
          TextSpan(text: joined, semanticsLabel: data),
          locale: jaLocale,
          style: style,
          textScaler: textScaler,
        );
}

/// 一段底字＋ruby（＋併進來的開括號、收尾字）。
///
/// ruby 比底字寬時可懸在相鄰、本身沒有 ruby 的字上（[RubyOverhang.resolve]），
/// 段寬 = max(底字寬, ruby 寬 − 兩側實際可懸掛量)，多出的寬度依 1:2:1
/// 分配到底字之間與兩端（[RubyFit]）。落在行首、行尾時由
/// [RubyOverhangBoundary] 取消超出容器那一側的懸掛，再重排一次。
class RubyBox extends SlottedMultiChildRenderObjectWidget<RubySlot, RenderBox> {
  const RubyBox({
    required this.base,
    required this.ruby,
    required this.baseLength,
    required this.rubyLength,
    this.leading,
    this.trailing,
    this.start,
    this.end,
    this.textScaler = TextScaler.noScaling,
    super.key,
  });

  final Widget base, ruby;
  final Widget? leading, trailing;

  /// 底字有幾個字；多出的寬度除以字數 = 字距。
  final int baseLength;

  /// ruby 有幾個字；ruby 寬 ÷ 字數 = 一個 ruby 字寬，是每側懸掛的上限。
  /// 0 表示沒有 ruby（只佔 ruby 列高度），不懸掛。
  final int rubyLength;

  /// 前後相鄰、沒有 ruby 的文字；null 表示那一側什麼都沒有（段首、段尾）。
  final RubyNeighbor? start, end;

  /// 子元件文字用的縮放，量相鄰文字時一致套用。
  final TextScaler textScaler;

  @override
  Iterable<RubySlot> get slots => RubySlot.values;

  @override
  Widget? childForSlot(RubySlot slot) => switch (slot) {
    RubySlot.leading => leading,
    RubySlot.base => base,
    RubySlot.ruby => ruby,
    RubySlot.trailing => trailing,
  };

  @override
  RenderRubyBox createRenderObject(BuildContext context) => RenderRubyBox(
    baseLength: baseLength,
    rubyLength: rubyLength,
    start: start,
    end: end,
    textScaler: textScaler,
  );

  @override
  void updateRenderObject(BuildContext context, RenderRubyBox renderObject) {
    renderObject
      ..baseLength = baseLength
      ..rubyLength = rubyLength
      ..start = start
      ..end = end
      ..textScaler = textScaler;
  }
}

/// 行首、行尾的容器：包住 `MixedText` 的 `RichText` 或 `RubyLine` 的 `Wrap`。
class RubyOverhangBoundary extends SingleChildRenderObjectWidget {
  const RubyOverhangBoundary({required Widget super.child, super.key});

  @override
  RenderRubyOverhangBoundary createRenderObject(BuildContext context) =>
      RenderRubyOverhangBoundary();
}

/// 換行位置要排過才知道，所以排完檢查哪些 ruby 超出容器、取消那一側的懸掛，
/// 再排一次，直到沒有新的超出。旗標只增不減，最多每盒兩次，一定會停。
class RenderRubyOverhangBoundary extends RenderProxyBox {
  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      super.performLayout();
      return;
    }
    final boxes = _rubyBoxesUnder(child);
    invokeLayoutCallback<BoxConstraints>((_) {
      for (final box in boxes) {
        box.clearLineEdges();
      }
    });
    _layout(child);
    for (var pass = 0; pass < boxes.length * 2; pass++) {
      if (!_flagLineEdges(boxes)) break;
      _layout(child);
    }
  }

  void _layout(RenderBox child) {
    child.layout(constraints, parentUsesSize: true);
    size = child.size;
  }

  bool _flagLineEdges(List<RenderRubyBox> boxes) {
    var isChanged = false;
    invokeLayoutCallback<BoxConstraints>((_) {
      for (final box in boxes) {
        isChanged = box.flagLineEdges(this) || isChanged;
      }
    });
    return isChanged;
  }

  static List<RenderRubyBox> _rubyBoxesUnder(RenderObject root) {
    final boxes = <RenderRubyBox>[];
    void visit(RenderObject node) {
      if (node is RenderRubyBox) {
        boxes.add(node);
      } else if (node is! RenderRubyOverhangBoundary) {
        node.visitChildren(visit);
      }
    }

    visit(root);
    return boxes;
  }
}

/// 底字目前的字距：原本的文字、換上去的文字。
typedef _BaseSpread = ({InlineSpan natural, TextSpan spaced});

typedef _Sizes = ({Size leading, Size base, Size ruby, Size trailing});

typedef _RowMeasure = ({
  BoxConstraints loose,
  BoxConstraints base,
  ChildBaselineGetter baselineOf,
});

typedef _Rows = ({
  double height,
  double rubyTop,
  double baseTop,
  double leadingTop,
  double trailingTop,
});

@immutable
final class _Geometry {
  const _Geometry({
    required this.size,
    required this.baseConstraints,
    required this.baseSpacing,
    required this.leading,
    required this.base,
    required this.ruby,
    required this.trailing,
  });

  final Size size;
  final BoxConstraints baseConstraints;
  final double baseSpacing;
  final Offset leading, base, ruby, trailing;
}

class RenderRubyBox extends RenderBox
    with
        SlottedContainerRenderObjectMixin<RubySlot, RenderBox>,
        RelayoutWhenSystemFontsChangeMixin {
  RenderRubyBox({
    required this._baseLength,
    required this._rubyLength,
    required this._start,
    required this._end,
    required this._textScaler,
  });

  int _baseLength;
  set baseLength(int value) {
    if (value == _baseLength) return;
    _baseLength = value;
    markNeedsLayout();
  }

  int _rubyLength;
  set rubyLength(int value) {
    if (value == _rubyLength) return;
    _rubyLength = value;
    markNeedsLayout();
  }

  RubyNeighbor? _start;
  set start(RubyNeighbor? value) {
    if (value == _start) return;
    _start = value;
    _startRun = null;
    markNeedsLayout();
  }

  RubyNeighbor? _end;
  set end(RubyNeighbor? value) {
    if (value == _end) return;
    _end = value;
    _endRun = null;
    markNeedsLayout();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _startRun = null;
    _endRun = null;
    markNeedsLayout();
  }

  /// 量好的相鄰文字（不含盒內併進來的字）；量一次就夠，字型變了再量。
  RubyRun? _startRun, _endRun;

  /// 這段落在行首、行尾：ruby 再懸出去就超出容器，這一側不懸掛。
  bool _isAtLineStart = false, _isAtLineEnd = false;

  _BaseSpread? _spread;

  @override
  void systemFontsDidChange() {
    _startRun = null;
    _endRun = null;
    super.systemFontsDidChange();
  }

  RenderBox? get _leading => childForSlot(RubySlot.leading);
  RenderBox? get _base => childForSlot(RubySlot.base);
  RenderBox? get _ruby => childForSlot(RubySlot.ruby);
  RenderBox? get _trailing => childForSlot(RubySlot.trailing);

  double _measure(TextSpan text) {
    final painter = TextPainter(
      text: text,
      textDirection: TextDirection.ltr,
      textScaler: _textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  RubyRun _measureRun(RubyNeighbor neighbor) {
    final far = neighbor.far;
    return RubyRun(
      width: _measure(neighbor.text) + neighbor.gap,
      shared: neighbor.shared,
      farExcess: far == null
          ? null
          : math.max(0, _measure(far.ruby) - _measure(far.base)),
    );
  }

  RubyRun _run(RubyNeighbor? neighbor, double inBox, {required bool isStart}) {
    if (neighbor == null) return RubyRun(width: inBox);
    final run = isStart
        ? _startRun ??= _measureRun(neighbor)
        : _endRun ??= _measureRun(neighbor);
    return RubyRun(
      width: inBox + run.width,
      shared: run.shared,
      farExcess: run.farExcess,
    );
  }

  RubyOverhang _overhang(double ruby, double leading, double trailing) =>
      RubyOverhang.resolve(
        rubyEm: _rubyLength > 0 ? ruby / _rubyLength : 0,
        start: _run(_isAtLineStart ? null : _start, leading, isStart: true),
        end: _run(_isAtLineEnd ? null : _end, trailing, isStart: false),
      );

  RubyFit _fit(
    double base,
    double ruby,
    double leading,
    double trailing,
    double maxWidth,
  ) => RubyFit.compute(
    base: base,
    ruby: ruby,
    baseLength: _baseLength,
    overhang: _overhang(ruby, leading, trailing),
    maxWidth: maxWidth,
  );

  _Geometry _compute(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
    ChildBaselineGetter baselineOf,
  ) {
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    final leading = _sizeOf(_leading, loose, layoutChild);
    final trailing = _sizeOf(_trailing, loose, layoutChild);
    final baseConstraints = BoxConstraints(
      maxWidth: math.max(
        0,
        constraints.maxWidth - leading.width - trailing.width,
      ),
    );
    final base = _sizeOf(_base, baseConstraints, layoutChild);
    final ruby = _sizeOf(_ruby, loose, layoutChild);
    final fit = _fit(
      base.width,
      ruby.width,
      leading.width,
      trailing.width,
      baseConstraints.maxWidth,
    );
    final rows = _rowsOf(
      (leading: leading, base: base, ruby: ruby, trailing: trailing),
      (loose: loose, base: baseConstraints, baselineOf: baselineOf),
    );
    final total = leading.width + fit.width + trailing.width;
    return _Geometry(
      size: constraints.constrain(Size(total, rows.height)),
      baseConstraints: baseConstraints,
      baseSpacing: fit.baseSpacing,
      leading: Offset(0, rows.leadingTop),
      base: Offset(leading.width, rows.baseTop),
      ruby: Offset(
        _rubyLeft(leading.width + fit.rubyLeft, ruby.width, total),
        rows.rubyTop,
      ),
      trailing: Offset(leading.width + fit.width, rows.trailingTop),
    );
  }

  /// 各列的高度位置：併進來的字和底字同一條基線。
  _Rows _rowsOf(_Sizes sizes, _RowMeasure measure) {
    final baseBaseline =
        _baselineOf(_base, measure.base, measure.baselineOf) ??
        sizes.base.height;
    double topOf(RenderBox? box, Size size) {
      final baseline =
          _baselineOf(box, measure.loose, measure.baselineOf) ?? size.height;
      return sizes.ruby.height + baseBaseline - baseline;
    }

    final leadingBox = _leading;
    final trailingBox = _trailing;
    final leadingTop = topOf(leadingBox, sizes.leading);
    final trailingTop = topOf(trailingBox, sizes.trailing);
    // 併進來的字比 ruby＋底字的基線還高時，整段往下移
    final shift = math.max(
      0.0,
      -math.min(
        leadingBox == null ? 0.0 : leadingTop,
        trailingBox == null ? 0.0 : trailingTop,
      ),
    );
    final height = [
      sizes.ruby.height + sizes.base.height,
      if (leadingBox != null) leadingTop + sizes.leading.height,
      if (trailingBox != null) trailingTop + sizes.trailing.height,
    ].reduce(math.max);
    return (
      height: height + shift,
      rubyTop: shift,
      baseTop: shift + sizes.ruby.height,
      leadingTop: shift + leadingTop,
      trailingTop: shift + trailingTop,
    );
  }

  /// 落在行首、行尾時，ruby 不超出段的那一側（比一行還長時才會用到）。
  double _rubyLeft(double left, double ruby, double total) {
    final min = _isAtLineStart ? 0.0 : double.negativeInfinity;
    final max = _isAtLineEnd ? math.max(min, total - ruby) : double.infinity;
    return left.clamp(min, max);
  }

  static Size _sizeOf(
    RenderBox? child,
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) => child == null ? Size.zero : layoutChild(child, constraints);

  static double? _baselineOf(
    RenderBox? child,
    BoxConstraints constraints,
    ChildBaselineGetter baselineOf,
  ) => child == null
      ? null
      : baselineOf(child, constraints, TextBaseline.alphabetic);

  _Geometry _dry(BoxConstraints constraints) => _compute(
    constraints,
    ChildLayoutHelper.dryLayoutChild,
    ChildLayoutHelper.getDryBaseline,
  );

  @override
  void performLayout() {
    _restoreBase();
    final geometry = _compute(
      constraints,
      ChildLayoutHelper.layoutChild,
      ChildLayoutHelper.getBaseline,
    );
    _spreadBase(geometry.baseSpacing);
    size = geometry.size;
    _place(_leading, geometry.leading);
    _place(_base, geometry.base);
    _place(_ruby, geometry.ruby);
    _place(_trailing, geometry.trailing);
  }

  void _restoreBase() {
    final spread = _spread;
    final base = _base;
    _spread = null;
    // 文字已被 widget 重建換掉時，就不用還原
    if (spread == null ||
        base is! RenderParagraph ||
        !identical(base.text, spread.spaced)) {
      return;
    }
    invokeLayoutCallback<BoxConstraints>((_) => base.text = spread.natural);
  }

  /// 字距要排版後才算得出來，`Text` 在 build 時給不了，
  /// 所以直接換掉底字 `RenderParagraph` 的文字；widget 重建會換回原文，再重排。
  void _spreadBase(double spacing) {
    final base = _base;
    if (spacing <= 0 || base is! RenderParagraph) return;
    final natural = base.text;
    if (natural is! TextSpan) return;
    final style = natural.style ?? const TextStyle();
    final spaced = TextSpan(
      text: natural.text,
      children: natural.children,
      locale: natural.locale,
      style: style.copyWith(
        letterSpacing: (style.letterSpacing ?? 0) + spacing,
      ),
    );
    invokeLayoutCallback<BoxConstraints>((_) => base.text = spaced);
    _spread = (natural: natural, spaced: spaced);
    // 不帶寬度上限：字距已算進段寬，捨入誤差不該讓最後一個字換行
    base.layout(const BoxConstraints(), parentUsesSize: true);
  }

  /// 由容器在 layout callback 裡呼叫：重排前清掉上次的行首、行尾判定。
  void clearLineEdges() {
    if (!_isAtLineStart && !_isAtLineEnd) return;
    _isAtLineStart = false;
    _isAtLineEnd = false;
    markNeedsLayout();
  }

  /// 由容器在 layout callback 裡呼叫：ruby 超出 [boundary] 時記下那一側。
  /// 有新的判定時回 true，容器要再排一次。
  bool flagLineEdges(RenderBox boundary) {
    final ruby = _ruby;
    if (ruby == null || _rubyLength == 0) return false;
    final left = (ruby.parentData! as BoxParentData).offset.dx;
    final transform = getTransformTo(boundary);
    final start = MatrixUtils.transformPoint(transform, Offset(left, 0)).dx;
    final end = MatrixUtils.transformPoint(
      transform,
      Offset(left + ruby.size.width, 0),
    ).dx;
    // 被 maxLines 截掉的段沒有位置，transform 全是 0
    if (!(end > start)) return false;
    final isNewStart = !_isAtLineStart && start < -_edgeEpsilon;
    final isNewEnd = !_isAtLineEnd && end > boundary.size.width + _edgeEpsilon;
    if (!isNewStart && !isNewEnd) return false;
    _isAtLineStart = _isAtLineStart || isNewStart;
    _isAtLineEnd = _isAtLineEnd || isNewEnd;
    markNeedsLayout();
    return true;
  }

  static void _place(RenderBox? child, Offset offset) {
    if (child == null) return;
    (child.parentData! as BoxParentData).offset = offset;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _dry(constraints).size;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final base = _base;
    if (base == null) return null;
    final geometry = _dry(constraints);
    final distance = base.getDryBaseline(geometry.baseConstraints, baseline);
    return distance == null ? null : distance + geometry.base.dy;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final base = _base;
    if (base == null) return null;
    final distance = base.getDistanceToActualBaseline(baseline);
    if (distance == null) return null;
    return distance + (base.parentData! as BoxParentData).offset.dy;
  }

  double _intrinsicWidth(double Function(RenderBox child) measure) {
    double of(RenderBox? child) => child == null ? 0.0 : measure(child);
    final leading = of(_leading);
    final trailing = of(_trailing);
    // ruby 不換行，一律用最寬的量法
    final ruby = _ruby?.getMaxIntrinsicWidth(double.infinity) ?? 0.0;
    final fit = _fit(of(_base), ruby, leading, trailing, double.infinity);
    return leading + fit.width + trailing;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicWidth((child) => child.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicWidth((child) => child.getMaxIntrinsicWidth(double.infinity));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _dry(BoxConstraints(maxWidth: width)).size.height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  static Offset _offsetOf(RenderBox child) =>
      (child.parentData! as BoxParentData).offset;

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(child, offset + _offsetOf(child));
    }
  }

  @override
  void applyPaintTransform(covariant RenderBox child, Matrix4 transform) {
    final offset = _offsetOf(child);
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final hit = result.addWithPaintOffset(
        offset: _offsetOf(child),
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
