import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/kana/chart/kana_static_chart.dart';

/// 內容 JSON 依字串化 id→char，比對靜態表不會和真實內容漂移。
Map<String, String> _content(String file, Set<String> kinds) {
  final raw = File('rust/content/kana/$file').readAsStringSync();
  final items = (jsonDecode(raw) as Map<String, dynamic>)['items'] as List;
  return {
    for (final item in items.cast<Map<String, dynamic>>())
      if (kinds.contains(item['kind']) && item['retired'] != true)
        item['id'] as String: item['char'] as String,
  };
}

/// 內容陣列的 id 順序；`kana_chart` 依此排列，靜態表要一致。
List<String> _contentOrder(String file, Set<String> kinds) =>
    _content(file, kinds).keys.toList();

List<String> _chartOrder(List<KanaGroupDto> chart, String title) =>
    _chartIds(chart, title).keys.toList();

List<String> _basicRowHeads(List<KanaGroupDto> chart) => [
  for (final row in chart.firstWhere((g) => g.titleZh == '清音').rows)
    row.cells.whereType<KanaCellDto>().first.ch,
];

Map<String, String> _chartIds(List<KanaGroupDto> chart, String title) {
  final group = chart.firstWhere((g) => g.titleZh == title);
  return {
    for (final row in group.rows)
      for (final cell in row.cells.whereType<KanaCellDto>()) cell.id: cell.ch,
  };
}

void main() {
  for (final (script, file) in [
    (KanaScript.hiragana, 'hiragana.json'),
    (KanaScript.katakana, 'katakana.json'),
  ]) {
    group('$script', () {
      final chart = staticKanaChart(script);

      test('清音與內容一致', () {
        expect(_chartIds(chart, '清音'), _content(file, {'basic'}));
      });
      test('濁音與半濁音與內容一致', () {
        expect(_chartIds(chart, '濁音與半濁音'), _content(file, {'dakuten'}));
      });
      test('拗音與內容一致', () {
        expect(_chartIds(chart, '拗音'), _content(file, {'yoon'}));
      });
      test('順序與內容陣列一致（Map 比對不看順序）', () {
        expect(_chartOrder(chart, '清音'), _contentOrder(file, {'basic'}));
        expect(_chartOrder(chart, '濁音與半濁音'), _contentOrder(file, {'dakuten'}));
        expect(_chartOrder(chart, '拗音'), _contentOrder(file, {'yoon'}));
      });
      test('每列欄數等於分區欄數，全為尚未開始', () {
        for (final group in chart) {
          for (final row in group.rows) {
            expect(row.cells, hasLength(group.columns));
            for (final cell in row.cells.whereType<KanaCellDto>()) {
              expect(cell.status, KanaStatus.notStarted);
              expect(cell.romaji, isNotEmpty);
            }
          }
        }
      });
    });
  }

  test('平假名與片假名的清音都是標準五十音順', () {
    expect(_basicRowHeads(staticKanaChart(KanaScript.hiragana)), const [
      'あ',
      'か',
      'さ',
      'た',
      'な',
      'は',
      'ま',
      'や',
      'ら',
      'わ',
      'ん',
    ]);
    expect(_basicRowHeads(staticKanaChart(KanaScript.katakana)), const [
      'ア',
      'カ',
      'サ',
      'タ',
      'ナ',
      'ハ',
      'マ',
      'ヤ',
      'ラ',
      'ワ',
      'ン',
    ]);
  });
}
