import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/vocab/vocab_labels.dart';
import 'package:japanese_learn_app/features/vocab/widgets/accent_line.dart';

void main() {
  group('lessonLabelOf', () {
    test('一般課與假名課分開標示，去掉前導零', () {
      expect(lessonLabelOf('le.l05'), '第 5 課');
      expect(lessonLabelOf('le.k03'), '平假名第 3 課');
      expect(lessonLabelOf('le.kk07'), '片假名第 7 課');
    });

    test('不認得的 ID 回空字串', () {
      expect(lessonLabelOf('dz.scene_01'), '');
    });
  });

  group('jlptLabelOf（O7）', () {
    test('P0a 只標 N5', () {
      expect(jlptLabelOf(JlptLevel.n5, ContentStage.p0A), '參考 N5');
      expect(jlptLabelOf(JlptLevel.n4, ContentStage.p0A), isNull);
      expect(jlptLabelOf(JlptLevel.beyond, ContentStage.p0A), isNull);
    });

    test('其他階段全標', () {
      expect(jlptLabelOf(JlptLevel.n4, ContentStage.p0), '參考 N4');
      expect(jlptLabelOf(JlptLevel.beyond, ContentStage.full), 'N4 以外');
    });

    test('p0 的三個級別都是單字逐字標示（V3），與範圍宣稱無關', () {
      expect(jlptLabelOf(JlptLevel.n5, ContentStage.p0), '參考 N5');
      expect(jlptLabelOf(JlptLevel.n4, ContentStage.p0), '參考 N4');
      expect(jlptLabelOf(JlptLevel.beyond, ContentStage.p0), 'N4 以外');
    });
  });

  test('srsFromQuery 認得列舉名稱，其餘為 null', () {
    expect(srsFromQuery('notStarted'), SrsStateLabel.notStarted);
    expect(srsFromQuery('mastered'), SrsStateLabel.mastered);
    expect(srsFromQuery('nope'), isNull);
    expect(srsFromQuery(null), isNull);
  });

  group('moraeOf', () {
    test('小寫假名併入前一拍，っ與ー自成一拍', () {
      expect(moraeOf('きょう'), ['きょ', 'う']);
      expect(moraeOf('がっこう'), ['が', 'っ', 'こ', 'う']);
      expect(moraeOf('コーヒー'), ['コ', 'ー', 'ヒ', 'ー']);
    });

    test('忽略空白', () {
      expect(moraeOf('こんにち は'), ['こ', 'ん', 'に', 'ち', 'は']);
    });
  });

  group('pitchOf', () {
    test('平板：第一拍低，其餘高', () {
      expect(pitchOf(3, 0), [false, true, true]);
    });

    test('頭高：第一拍高，其餘低', () {
      expect(pitchOf(3, 1), [true, false, false]);
    });

    test('中高：第 n 拍後下降', () {
      expect(pitchOf(4, 2), [false, true, false, false]);
      expect(pitchOf(4, 3), [false, true, true, false]);
    });
  });
}
