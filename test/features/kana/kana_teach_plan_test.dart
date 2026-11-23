import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/kana/session/kana_teach_plan.dart';

import '../../support/fixtures.dart';
import '../quiz/quiz_fixtures.dart';
import 'kana_fixtures.dart';

void main() {
  final nu = kanaCellFixture(id: 'ka.hira.nu', ch: 'ぬ', romaji: 'nu');
  const diff = '{ja:ぬ} 收筆有圈';
  final nuGroup = ConfusableDto(
    id: 'ka.cf.nu_me',
    kind: ConfusableKindDto.shape,
    members: [nu],
    literals: const [],
    diffZh: diff,
  );

  group('kanaTargetsOf', () {
    test('收集 reference 與 focus，只留 ka.hira／ka.kata', () {
      final targets = kanaTargetsOf([
        kanaRead('ka.hira.a', 'あ', correct: 'a'),
        questionFixture(
          QuestionType.minimalPair,
          choiceBodyFixture(),
          reference: refFixture(
            QuestionType.minimalPair,
            contentId: 'ka.rule.sokuon',
          ),
          focusIds: const ['ka.kata.a', 'ka.cf.nu_me', 'gr.wa'],
        ),
        matchQuestion(),
      ]);
      expect(targets, {'ka.hira.a', 'ka.kata.a'});
    });
  });

  group('rulesToTeach', () {
    final rule = ruleCardFixture();

    LessonDetailDto lesson(LessonStatus status, List<KanaCellDto> kana) {
      final base = lessonOf(kana, rules: [rule]);
      return LessonDetailDto(
        summary: LessonSummaryDto(
          id: base.summary.id,
          stageId: base.summary.stageId,
          titleZh: base.summary.titleZh,
          canDoZh: base.summary.canDoZh,
          status: status,
        ),
        kana: base.kana,
        rules: base.rules,
        words: base.words,
        grammar: base.grammar,
        integrationDaysDone: 0,
        integrationDaysNeeded: 0,
      );
    }

    test('沒有字的規則課，未完成時呈現規則', () {
      expect(rulesToTeach(lesson(LessonStatus.current, const [])), [rule]);
      expect(rulesToTeach(lesson(LessonStatus.notStarted, const [])), [rule]);
    });

    test('課完成或略過就不再呈現', () {
      expect(rulesToTeach(lesson(LessonStatus.done, const [])), isEmpty);
      expect(rulesToTeach(lesson(LessonStatus.skipped, [nu])), isEmpty);
    });

    test('課內有字且都學過時直接測驗', () {
      final learned = kanaCellFixture(status: KanaStatus.learning);
      expect(rulesToTeach(lesson(LessonStatus.current, [learned])), isEmpty);
      expect(rulesToTeach(lesson(LessonStatus.current, [nu])), [rule]);
    });
  });

  group('buildTeachSteps', () {
    test('順序是字、規則、字組', () {
      final steps = buildTeachSteps(
        [
          detailOf(nu, confusables: [nuGroup]),
        ],
        [kanaConfuse('ka.hira.nu', 'nu', explain: diff)],
        rules: [ruleCardFixture()],
      );
      expect(steps[0], isA<KanaCharStep>());
      expect(steps[1], isA<KanaRuleStep>());
      expect(steps[2], isA<KanaConfusableStep>());
    });

    test('只教尚未開始的字，維持傳入順序', () {
      final learning = kanaCellFixture(status: KanaStatus.learning);
      final steps = buildTeachSteps([
        detailOf(learning),
        detailOf(nu),
      ], const []);
      expect(steps, hasLength(1));
      expect((steps.single as KanaCharStep).detail.cell.id, 'ka.hira.nu');
    });

    test('有 kana_confuse 題時，字組排在字之後且不重複', () {
      final steps = buildTeachSteps(
        [
          detailOf(nu, confusables: [nuGroup]),
        ],
        [
          kanaConfuse('ka.hira.nu', 'nu', explain: diff),
          kanaConfuse('ka.hira.nu', 'nu', explain: diff),
        ],
      );
      expect(steps, hasLength(2));
      expect(steps.first, isA<KanaCharStep>());
      expect((steps.last as KanaConfusableStep).group.id, 'ka.cf.nu_me');
    });

    test('題目的字已學過時不教字組', () {
      final learning = kanaCellFixture(
        id: 'ka.hira.nu',
        ch: 'ぬ',
        romaji: 'nu',
        status: KanaStatus.learning,
      );
      final steps = buildTeachSteps(
        [
          detailOf(learning, confusables: [nuGroup]),
        ],
        [kanaConfuse('ka.hira.nu', 'nu', explain: diff)],
      );
      expect(steps, isEmpty);
    });

    test('沒有對應題目的字組不教', () {
      final steps = buildTeachSteps([
        detailOf(nu, confusables: [nuGroup]),
      ], const []);
      expect(steps.whereType<KanaConfusableStep>(), isEmpty);
    });
  });
}
