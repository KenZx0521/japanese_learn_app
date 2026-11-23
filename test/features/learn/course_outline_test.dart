import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/learn/course_outline.dart';

import '../../support/fixtures.dart';
import 'learn_fixtures.dart';

void main() {
  group('courseOutline', () {
    test('依階段分組，沒有課的階段不出現（O7）', () {
      final outline = courseOutline(mixedOverview());

      expect(outline.map((s) => s.stage.id), ['st.s0', 'st.s1']);
    });

    test('假名階段拆成平假名與片假名兩段，順序與學習順序相同', () {
      final kana = courseOutline(mixedOverview()).first;

      expect(kana.sections.map((s) => s.title), ['平假名與發音規則', '片假名']);
      expect(kana.sections.first.lessons.map((l) => l.id), [
        'le.k01',
        'le.k02',
      ]);
      expect(kana.sections.last.lessons.map((l) => l.id), [
        'le.kk01',
        'le.kk02',
      ]);
    });

    test('片假名那一段會說明它和主線課輪流學', () {
      final kana = courseOutline(mixedOverview()).first;

      expect(kana.sections.first.note, isNull);
      expect(kana.sections.last.note, isNotNull);
    });

    test('只有一段的階段不需要段落標題', () {
      final main = courseOutline(mixedOverview()).last;

      expect(main.sections, hasLength(1));
      expect(main.sections.single.title, isNull);
      expect(main.sections.single.lessons.map((l) => l.id), [
        'le.l01',
        'le.l02',
        'le.l03',
      ]);
    });

    test('學完與略過都算完成，目前與未到的不算', () {
      final outline = courseOutline(mixedOverview());

      expect(outline.first.finished, 2);
      expect(outline.first.total, 4);
      expect(outline.first.sections.first.finished, 2);
      expect(outline.first.sections.last.finished, 0);
      expect(outline.last.finished, 1);
    });

    test('段落知道目前的課是否在自己裡面', () {
      final sections = courseOutline(mixedOverview()).first.sections;

      expect(sections.first.holds('le.kk01'), isFalse);
      expect(sections.last.holds('le.kk01'), isTrue);
      expect(sections.last.holds(null), isFalse);
    });

    test('沒有課時回傳空清單', () {
      expect(courseOutline(mixedOverview(lessons: const [])), isEmpty);
    });
  });

  group('lessonAfter', () {
    test('回傳學習順序的下一課，假名課與主線課交錯', () {
      final lessons = mixedLessons();

      expect(lessonAfter(lessons, 'le.kk01')?.id, 'le.l02');
      expect(lessonAfter(lessons, 'le.l02')?.id, 'le.kk02');
    });

    test('跳過已完成或略過的課', () {
      final lessons = mixedLessons();

      expect(lessonAfter(lessons, 'le.k01')?.id, 'le.kk01');
    });

    test('最後一課或找不到時回 null', () {
      final lessons = mixedLessons();

      expect(lessonAfter(lessons, 'le.l03'), isNull);
      expect(lessonAfter(lessons, 'le.nope'), isNull);
      expect(lessonAfter(lessons, null), isNull);
    });
  });

  group('isKanaLesson', () {
    test('平假名與片假名課都算，主線課不算', () {
      expect(isKanaLesson('le.k01'), isTrue);
      expect(isKanaLesson('le.kk08'), isTrue);
      expect(isKanaLesson('le.l01'), isFalse);
    });
  });

  group('canPracticeKana', () {
    LessonDetailDto kanaLesson({
      List<KanaCellDto> kana = const [],
      List<RuleCardDto> rules = const [],
    }) => lessonDetail(summary: kanaSummary(), kana: kana, rules: rules);

    test('有新字的假名課可以練', () {
      expect(canPracticeKana(kanaLesson(kana: [kanaCellFixture()])), isTrue);
    });

    test('沒有新字也沒有規則卡的總檢課可以練（題目來自易混字組）', () {
      expect(canPracticeKana(kanaLesson()), isTrue);
    });

    test('規則卡掛了演練的課可以練', () {
      final rules = [
        ruleOf(drillIds: const ['dr.k17.mpr.001']),
      ];

      expect(canPracticeKana(kanaLesson(rules: rules)), isTrue);
    });

    test('只有規則說明、沒有任何題目的課不提供練習', () {
      expect(canPracticeKana(kanaLesson(rules: [ruleOf()])), isFalse);
    });

    test('主線課不走 K2', () {
      expect(canPracticeKana(lessonDetail()), isFalse);
    });
  });
}
