import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/course_groups.dart';

import '../../features/grammar/grammar_fixtures.dart';

void main() {
  group('lessonNumberLabel', () {
    test('主線課回課次，去掉前導零', () {
      expect(lessonNumberLabel('le.l21'), '第 21 課');
      expect(lessonNumberLabel('le.l05'), '第 5 課');
    });

    // 裁決 U11：課 id 規則見 rust/content/course.json（le.k01–k19、le.kk01–kk08）
    test('平假名課（le.kNN）回「平假名第 N 課」', () {
      expect(lessonNumberLabel('le.k03'), '平假名第 3 課');
      expect(lessonNumberLabel('le.k19'), '平假名第 19 課');
    });

    test('片假名課（le.kkNN）回「片假名第 N 課」', () {
      expect(lessonNumberLabel('le.kk02'), '片假名第 2 課');
      expect(lessonNumberLabel('le.kk08'), '片假名第 8 課');
    });

    test('無法辨識的 id 才退回原始 id', () {
      for (final id in ['weird', 'le.x01', 'le.l', 'le.k', 'le.kkk01', '']) {
        expect(lessonNumberLabel(id), id, reason: id);
      }
    });
  });

  group('lessonHeadline', () {
    test('主線課是課次加課名', () {
      expect(
        lessonHeadline(lessonFixture('le.l05', titleZh: '多少錢')),
        '第 5 課  多少錢',
      );
    });

    test('假名課的課名已說明內容，不加課次', () {
      expect(
        lessonHeadline(lessonFixture('le.k02', titleZh: '{ja:か}行')),
        '{ja:か}行',
      );
      expect(
        lessonHeadline(lessonFixture('le.kk01', titleZh: '{ja:ア}行')),
        '{ja:ア}行',
      );
    });
  });

  group('isMainLesson', () {
    test('只有 le.lNN 是主線課', () {
      expect(isMainLesson('le.l01'), isTrue);
      expect(isMainLesson('le.l30'), isTrue);
      expect(isMainLesson('le.k01'), isFalse);
      expect(isMainLesson('le.kk01'), isFalse);
      expect(isMainLesson('weird'), isFalse);
    });
  });
}
