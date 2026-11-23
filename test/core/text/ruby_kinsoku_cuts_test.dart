// U2：禁則切分的純計算。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/text/ruby_kinsoku.dart';

import 'ruby_geometry.dart';

KinsokuAtom _text(String text) => KinsokuAtom(text);

KinsokuAtom _box(String text, {bool isFixed = true}) =>
    KinsokuAtom(text, isBox: true, isFixed: isFixed);

String _moved(List<KinsokuMove> moves) => moves.map((m) => m.text).join();

void main() {
  group('字元分類', () {
    for (final char in noLineStartChars.split('')) {
      test('$char 不能在行首', () {
        expect(noLineStartPrefix('$char後'), char);
      });
    }

    for (final char in noLineEndChars.split('')) {
      test('$char 不能在行尾', () {
        expect(noLineEndSuffix('前$char'), char);
      });
    }

    test('半形括號｢｣也算', () {
      expect(noLineEndSuffix('前｢'), '｢');
      expect(noLineStartPrefix('｣後'), '｣');
    });

    test('一般的字不切', () {
      expect(noLineStartPrefix('かな。'), '');
      expect(noLineEndSuffix('「かな'), '');
    });

    test('連續的字一起切', () {
      expect(noLineStartPrefix('」。後'), '」。');
      expect(noLineEndSuffix('前（「'), '（「');
    });

    test('isOpeningText：全部都是開括號才算', () {
      expect(isOpeningText('「'), isTrue);
      expect(isOpeningText('（「'), isTrue);
      expect(isOpeningText('」「'), isFalse);
      expect(isOpeningText(''), isFalse);
    });

    test('startsNoLineStart：看第一個字', () {
      expect(startsNoLineStart('って'), isTrue);
      expect(startsNoLineStart('てって'), isFalse);
      expect(startsNoLineStart(''), isFalse);
    });
  });

  group('withLineStartJoiners', () {
    test('小書き假名、長音、疊字前加 WORD JOINER', () {
      expect(withLineStartJoiners('しゅっぱつ'), 'し\u2060ゅ\u2060っぱつ');
      expect(withLineStartJoiners('コーヒー'), 'コ\u2060ーヒ\u2060ー');
      expect(withLineStartJoiners('人々'), '人\u2060々');
    });

    test('開頭的字不加：單獨舉例的假名可以在行首', () {
      expect(withLineStartJoiners('っ'), 'っ');
      expect(withLineStartJoiners('って'), 'って');
      expect(withLineStartJoiners('って', afterText: true), '\u2060って');
      expect(withLineStartJoiners('かな', afterText: true), 'かな');
    });

    test('沒有這些字時原樣回傳', () {
      expect(withLineStartJoiners('かな'), 'かな');
      expect(withLineStartJoiners(''), '');
    });

    test('標點交給文字引擎，不加', () {
      expect(withLineStartJoiners('かな。」'), 'かな。」');
    });
  });

  group('withNoBreakSpaces', () {
    test('空白後面接不能在行首的字時換成不換行的空白', () {
      expect(withNoBreakSpaces('まだ …'), 'まだ\u00A0…');
      expect(withNoBreakSpaces('加上 ', next: 'って'), '加上\u00A0');
    });

    test('其他空白不動', () {
      expect(withNoBreakSpaces('中文 中文'), '中文 中文');
      expect(withNoBreakSpaces('結尾 '), '結尾 ');
      expect(withNoBreakSpaces('結尾 ', next: '中文'), '結尾 ');
    });
  });

  group('kinsokuCuts', () {
    test('盒子後面的收尾字併進盒子，留下其餘', () {
      final cuts = kinsokuCuts([_box('語'), _text('。後面')]);

      expect(_moved(cuts[0].trailing), '。');
      expect(cuts[0].trailing.single.atom, 1);
      expect(cuts[1].body, '後面');
      expect(cuts[1].tail, '');
    });

    test('盒子前面的開括號併進盒子，tail 記下被拿走的字', () {
      final cuts = kinsokuCuts([_text('中文「'), _box('語')]);

      expect(_moved(cuts[1].leading), '「');
      expect(cuts[0].body, '中文');
      expect(cuts[0].tail, '「');
    });

    test('沒有盒子的文字之間不切', () {
      final cuts = kinsokuCuts([_text('中文「'), _text('。後面')]);

      expect(cuts[0].body, '中文「');
      expect(cuts[1].body, '。後面');
    });

    test('沒有 ruby 的盒子可以被前一盒切，也會切後面的字', () {
      final cuts = kinsokuCuts([
        _box('知'),
        _box('ってる', isFixed: false),
        _text('、後面'),
      ]);

      expect(_moved(cuts[0].trailing), 'っ');
      expect(cuts[1].body, 'てる');
      expect(_moved(cuts[1].trailing), '、');
      expect(cuts[2].body, '後面');
    });

    test('有 ruby 的盒子本身不被切', () {
      final cuts = kinsokuCuts([_box('知'), _box('々')]);

      expect(cuts[0].trailing, isEmpty);
      expect(cuts[1].body, '々');
    });

    test('整段被拿走時繼續往後拿，空盒不再收字', () {
      final cuts = kinsokuCuts([
        _box('待'),
        _box('っ', isFixed: false),
        _text('。後面'),
      ]);

      expect(_moved(cuts[0].trailing), 'っ。');
      expect(cuts[1].body, '');
      expect(cuts[1].trailing, isEmpty);
      expect(cuts[2].body, '後面');
    });

    test('夾在兩盒之間的字：開頭給前盒、結尾給後盒', () {
      final cuts = kinsokuCuts([_box('一'), _text('」和「'), _box('二')]);

      expect(_moved(cuts[0].trailing), '」');
      expect(cuts[1].body, '和');
      expect(_moved(cuts[2].leading), '「');
    });

    test('往前拿時順序不變', () {
      final cuts = kinsokuCuts([_text('（'), _text('「'), _box('語')]);

      expect(_moved(cuts[2].leading), '（「');
      expect(cuts[2].leading.first.atom, 0);
    });

    test('文字全部是收尾字時不會再被後盒當開括號', () {
      final cuts = kinsokuCuts([_box('一'), _text('。'), _box('二')]);

      expect(_moved(cuts[0].trailing), '。');
      expect(cuts[2].leading, isEmpty);
    });
  });
}
