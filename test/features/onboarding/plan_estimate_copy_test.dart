// review_fc F8：O4 的粗估文案改用 scope_copy（flutter-app §3.1「範圍文案集中在 scope_copy」）。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/onboarding/plan_estimate_copy.dart';
import 'package:japanese_learn_app/features/plan/scope_copy.dart';

import '../../support/fixtures.dart';

PlanViewDto _plan({String? mainEnd = '2026-08-12'}) => PlanViewDto(
  input: planInputFixture(),
  currentLessonId: 'le.k01',
  milestones: const [],
  mainForecastEnd: mainEnd,
  status: PlanStatus.onTrack,
);

void main() {
  test('沒有主線完成日時不列', () {
    expect(estimateLines(_plan(mainEnd: null), ContentStage.p0), isEmpty);
  });

  // 每個階段都只有主線這一行。
  test('各階段的主線行與 P1 的 forecastLine 逐字相同', () {
    for (final stage in ContentStage.values) {
      expect(estimateLines(_plan(), stage), [
        forecastLine(stage, '2026-08-12'),
      ]);
    }
  });

  test('full 只有一行，寫完整版到 L48', () {
    expect(estimateLines(_plan(), ContentStage.full), [
      '完整版到 L48，約在 8/12 完成（粗估）',
    ]);
  });

  test('階段還沒載入時只說日期', () {
    expect(estimateLines(_plan(), null), ['約在 8/12 完成（粗估）']);
  });
}
