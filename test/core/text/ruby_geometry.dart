// 振假名排版測試共用的量測工具：每個字的位置、每一行的文字。
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:material_ui/material_ui.dart';

const geometryEps = 0.5;

/// `MixedText` 的語意節點在裡面的 `RichText` 上。
Finder mixedParagraph() => find
    .descendant(of: find.byType(MixedText), matching: find.byType(RichText))
    .first;

/// 不能落在行首的字（U2）。
const noLineStartChars =
    '。、，．！？：；）」』】〉》〕］｝…,.!?:;)]}'
    'ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶー々ゝゞヽヾ';

/// 不能落在行尾的字（U2）。
const noLineEndChars = '「『（【〈《〔［｛([{';

Rect rectOf(WidgetTester tester, String text, [int index = 0]) =>
    tester.getRect(find.text(text).at(index));

RenderParagraph _paragraphOf(WidgetTester tester, String text, int index) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.text(text).at(index),
        matching: find.byType(RichText),
      ),
    );

/// 底字每個字的字形範圍（全域座標）。假設是全形字，字寬 = 字級。
List<({double left, double right})> baseCells(
  WidgetTester tester,
  String text, [
  int index = 0,
]) {
  final paragraph = _paragraphOf(tester, text, index);
  final origin = paragraph.localToGlobal(Offset.zero).dx;
  final scale = paragraph.localToGlobal(const Offset(1, 0)).dx - origin;
  final fontSize = paragraph.text.style?.fontSize ?? 0;
  final advance = paragraph.textScaler.scale(fontSize) * scale;
  return [
    for (var i = 0; i < text.length; i++)
      () {
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: i, extentOffset: i + 1),
            )
            .first;
        final left = origin + box.left * scale;
        return (left: left, right: left + advance);
      }(),
  ];
}

/// 每側懸出底字至多一個 ruby 字寬；貼齊容器邊的 ruby 兩側合計也至多一個字寬。
void expectEdgeHang({
  required Rect base,
  required Rect ruby,
  required int rubyChars,
  required double width,
  required String reason,
}) {
  final limit = ruby.width / rubyChars + geometryEps;
  final startHang = math.max(0.0, base.left - ruby.left);
  final endHang = math.max(0.0, ruby.right - base.right);
  final detail = '$reason base=$base ruby=$ruby';
  expect(startHang, lessThanOrEqualTo(limit), reason: detail);
  expect(endHang, lessThanOrEqualTo(limit), reason: detail);
  final isFlush = ruby.left.abs() <= 0.01 || (width - ruby.right).abs() <= 0.01;
  if (isFlush) {
    expect(startHang + endHang, lessThanOrEqualTo(limit), reason: detail);
  }
}

typedef _Glyph = ({String char, Rect rect});

List<_Glyph> _glyphsOf(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  return [
    for (var i = 0; i < text.length; i++)
      // WORD JOINER 零寬，算進來的話行首的小書き假名會被它遮住
      if (text[i] != '￼' && text[i] != '\u2060' && text[i].trim().isNotEmpty)
        for (final box
            in paragraph
                .getBoxesForSelection(
                  TextSelection(baseOffset: i, extentOffset: i + 1),
                )
                .take(1))
          (
            char: text[i],
            rect: MatrixUtils.transformRect(
              paragraph.getTransformTo(null),
              box.toRect(),
            ),
          ),
  ];
}

/// [root] 底下畫出來的每一行文字（由上到下，不含 [ignore] 裡的讀音）。
List<String> linesOf(
  WidgetTester tester,
  Finder root, {
  Set<String> ignore = const {},
  double tolerance = 12,
}) {
  final glyphs = [
    for (final element
        in find
            .descendant(of: root, matching: find.byType(RichText))
            .evaluate())
      if (!ignore.contains(
        (element.widget as RichText).text.toPlainText(
          includeSemanticsLabels: false,
        ),
      ))
        ..._glyphsOf(element.renderObject! as RenderParagraph),
  ]..sort((a, b) => a.rect.center.dy.compareTo(b.rect.center.dy));
  final rows = <List<_Glyph>>[];
  for (final glyph in glyphs) {
    final isSameRow =
        rows.isNotEmpty &&
        (rows.last.first.rect.center.dy - glyph.rect.center.dy).abs() <=
            tolerance;
    if (isSameRow) {
      rows.last.add(glyph);
    } else {
      rows.add([glyph]);
    }
  }
  return [
    for (final row in rows)
      (row..sort((a, b) => a.rect.left.compareTo(b.rect.left)))
          .map((glyph) => glyph.char)
          .join(),
  ];
}

/// 每一行的行首、行尾都不違反禁則。
void expectKinsoku(List<String> lines, String reason) {
  for (final (index, line) in lines.indexed) {
    if (index > 0) {
      expect(
        noLineStartChars.contains(line[0]),
        isFalse,
        reason: '$reason：第 ${index + 1} 行以「${line[0]}」開頭 $lines',
      );
    }
    if (index < lines.length - 1) {
      expect(
        noLineEndChars.contains(line[line.length - 1]),
        isFalse,
        reason: '$reason：第 ${index + 1} 行以「${line[line.length - 1]}」結尾 $lines',
      );
    }
  }
}
