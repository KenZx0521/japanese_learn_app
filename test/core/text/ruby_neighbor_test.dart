// U1：找出每段 ruby 前後可以懸掛的文字。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/text/ruby_neighbor.dart';
import 'package:material_ui/material_ui.dart';

const _zh = TextStyle(fontSize: 16);
const _ja = TextStyle(fontSize: 17);

RubyPiece _plain(String text, {double gap = 0, TextStyle style = _zh}) =>
    RubyPiece(
      TextSpan(text: text, style: style),
      gapBefore: gap,
    );

RubyPiece _ruby(String text, {double gap = 0, String? reading}) => RubyPiece(
  TextSpan(text: text, style: _ja),
  hasRuby: true,
  ruby: reading == null ? null : TextSpan(text: reading, style: _zh),
  gapBefore: gap,
);

void main() {
  test('前後都是中文：收集相鄰文字，另一頭沒有 ruby', () {
    final edges = rubyEdgesOf([
      _plain('語調上揚的「'),
      _ruby('大丈夫'),
      _plain('是「你沒事吧？」'),
    ], 1);

    expect(edges.start?.text.toPlainText(), '語調上揚的「');
    expect(edges.start?.shared, isFalse);
    expect(edges.end?.text.toPlainText(), '是「你沒事吧？」');
    expect(edges.end?.shared, isFalse);
  });

  test('段首、段尾沒有相鄰文字時回 null', () {
    final pieces = [_ruby('大丈夫'), _plain('の'), _ruby('大丈夫')];

    final first = rubyEdgesOf(pieces, 0);
    final last = rubyEdgesOf(pieces, 2);

    expect(first.start, isNull);
    expect(first.end?.text.toPlainText(), 'の');
    expect(first.end?.shared, isTrue);
    expect(last.start?.shared, isTrue);
    expect(last.end, isNull);
  });

  test('只量靠近這段的 8 個字', () {
    final edges = rubyEdgesOf([
      _plain('一二三四五六'),
      _plain('七八九十'),
      _ruby('私'),
      _plain('甲乙丙丁戊己庚辛壬癸'),
    ], 2);

    expect(edges.start?.text.toPlainText(), '三四五六七八九十');
    expect(edges.end?.text.toPlainText(), '甲乙丙丁戊己庚辛');
  });

  test('每段保留自己的樣式', () {
    final edges = rubyEdgesOf([
      _ruby('台北'),
      _plain('に', style: _ja),
      _plain('去'),
    ], 0);

    final children = edges.end!.text.children!.cast<TextSpan>();
    expect(children.map((span) => span.style), [_ja, _zh]);
  });

  test('詞距算進相鄰寬度，跨到下一段 ruby 前的詞距也算', () {
    final edges = rubyEdgesOf([
      _ruby('私'),
      _plain('は', gap: 7.5),
      _ruby('学生', gap: 7.5),
    ], 0);

    expect(edges.end?.text.toPlainText(), 'は');
    expect(edges.end?.gap, 15);
    expect(edges.end?.shared, isTrue);
  });

  test('另一頭的 ruby 段附上它的底字與讀音，供估它最多懸出多少', () {
    final edges = rubyEdgesOf([
      _ruby('私', reading: 'わたし'),
      _plain('は'),
      _ruby('学生', reading: 'がくせい'),
    ], 0);

    expect(edges.end?.far?.base.toPlainText(), '学生');
    expect(edges.end?.far?.ruby.toPlainText(), 'がくせい');
    expect(edges.start, isNull);
  });

  test('另一頭是空格（沒有讀音）時不附', () {
    final edges = rubyEdgesOf([_ruby('私', reading: 'わたし'), _ruby('')], 0);

    expect(edges.end?.shared, isTrue);
    expect(edges.end?.far, isNull);
  });

  test('緊鄰另一段 ruby：寬度 0、另一頭有 ruby', () {
    final edges = rubyEdgesOf([_ruby('東京'), _ruby('大学')], 0);

    expect(edges.end?.text.toPlainText(), '');
    expect(edges.end?.gap, 0);
    expect(edges.end?.shared, isTrue);
  });

  test('endSkip 跳過已放進同一盒的收尾標點', () {
    final edges = rubyEdgesOf([_ruby('大学'), _plain('。')], 0, endSkip: 1);

    expect(edges.end, isNull);
  });
}
