import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/plan/scope_copy.dart';
import 'package:japanese_learn_app/features/today/expectation_copy.dart';

String _allText(ContentStage stage) {
  final copy = scopeCopyOf(stage);
  return [
    copy.opening,
    copy.canDo,
    copy.cannotDo,
    ...copy.references,
    ...copy.goals.expand((g) => [g.goal, g.reach, g.limit]),
    copy.notCovered ?? '',
    forecastLine(stage, '2027-03-15'),
  ].join('\n');
}

void main() {
  group('完成日文案（§3.8 文案表，逐字）', () {
    test('p0a 只說假名與入門七課', () {
      expect(
        forecastLine(ContentStage.p0A, '2027-03-15'),
        '假名與入門七課約在 3/15 完成（粗估）',
      );
    });

    test('p0 寫本版到 L30', () {
      expect(
        forecastLine(ContentStage.p0, '2027-03-05'),
        '本版到 L30，約在 3/5 完成（粗估）',
      );
    });

    test('full 寫完整版到 L48', () {
      expect(
        forecastLine(ContentStage.full, '2027-11-30'),
        '完整版到 L48，約在 11/30 完成（粗估）',
      );
    });

    test('階段還不知道時只說日期', () {
      expect(forecastLine(null, '2027-03-15'), '約在 3/15 完成（粗估）');
    });
  });

  group('程度說明（O7）', () {
    test('p0a 的開頭與能力逐字符合 §3.1', () {
      final copy = scopeCopyOf(ContentStage.p0A);
      expect(copy.opening, '這一版涵蓋假名與入門七課。');
      expect(copy.canDo, '讀出全部假名、聽辨清濁長短；用背好的句型打招呼、自我介紹、約人');
      expect(copy.cannotDo, '沒有真人對話對象，口說只有跟讀與選擇回應；語音由裝置合成');
    });

    test('p0a 不提 N4、不承諾日劇、也不露出專區', () {
      final text = _allText(ContentStage.p0A);
      for (final banned in ['N4', '看懂日劇', '聽懂日劇', '日劇', '專區', 'L30', 'L48']) {
        expect(text, isNot(contains(banned)), reason: banned);
      }
      expect(text, contains('假名與入門七課'));
    });

    test('p0 寫參考 N5，不宣稱 N4 或 L48', () {
      final text = _allText(ContentStage.p0);
      expect(text, contains('本版到 L30'));
      expect(text, contains('參考 N5'));
      expect(text, isNot(contains('N4')));
      expect(text, isNot(contains('L48')));
    });

    test('p0 不提 L31 以後的課與完整版，目標只列日常對話與 JLPT', () {
      final text = _allText(ContentStage.p0);
      expect(text, isNot(matches(RegExp(r'L(3[1-9]|4\d)'))));
      expect(text, isNot(contains('完整版')));
      expect(scopeCopyOf(ContentStage.p0).goals.map((g) => g.goal), [
        '日常對話',
        'JLPT',
      ]);
    });

    test('O6 的 p0 文案與 P2 開頭一致，三段都不提 N4（§3.1 表）', () {
      final copy = expectationCopy(ContentStage.p0);
      expect(copy.intro, scopeCopyOf(ContentStage.p0).opening);
      expect(copy.intro, '本版到 L30，涵蓋參考 N5 範圍。');
      for (final line in [copy.intro, copy.can, copy.cannot]) {
        expect(line, isNot(contains('N4')));
        expect(line, isNot(matches(RegExp(r'L(3[1-9]|4\d)'))));
      }
    });

    test('full 引用 §1.2 的 N4 基準與做不到的部分', () {
      final copy = scopeCopyOf(ContentStage.full);
      expect(copy.opening, '完整版到 L48。');
      final text = _allText(ContentStage.full);
      expect(text, contains('N4 總分 90 以上為 A2'));
      expect(text, contains('不保證通過 N4'));
      expect(copy.goals.map((g) => g.goal), ['日常對話', 'JLPT']);
    });

    test('級別一律標明非官方', () {
      for (final stage in [ContentStage.p0, ContentStage.full]) {
        expect(scopeCopyOf(stage).references.join(), contains('沒有官方單字與文法清單'));
      }
    });
  });

  group('日期與課次', () {
    test('月日', () {
      expect(monthDayOf('2027-01-09'), '1/9');
    });

    test('課次標籤區分三種課', () {
      expect(lessonOrdinalOf('le.k03'), '假名 第 3 課');
      expect(lessonOrdinalOf('le.kk02'), '片假名 第 2 課');
      expect(lessonOrdinalOf('le.l07'), '第 7 課');
      expect(lessonOrdinalOf('weird'), isNull);
    });

    test('換日前算前一天', () {
      expect(logicalDateOf(DateTime(2026, 11, 9, 3, 59), 4), '2026-11-08');
      expect(logicalDateOf(DateTime(2026, 11, 9, 4), 4), '2026-11-09');
      expect(logicalDateOf(DateTime(2026, 11, 9, 0, 30), 0), '2026-11-09');
    });

    test('兩個日期的天數差', () {
      expect(daysBetween('2027-03-15', '2027-03-20'), 5);
      expect(daysBetween('2027-03-20', '2027-03-15'), -5);
    });
  });
}
