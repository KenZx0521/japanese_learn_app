import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/back_line.dart';
import 'package:japanese_learn_app/design/widgets/kana_cell.dart';
import 'package:japanese_learn_app/features/kana/kana_chart_screen.dart';
import 'package:japanese_learn_app/features/learn/lesson_detail_sections.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

KanaRowDto _row(String prefix, int count) => KanaRowDto(
  cells: [
    for (var i = 0; i < count; i++)
      kanaCellFixture(id: '$prefix$i', ch: 'か', romaji: 'ka'),
  ],
);

List<KanaGroupDto> _groups() => [
  KanaGroupDto(titleZh: '清音', columns: 5, rows: [_row('a', 5), _row('b', 5)]),
  KanaGroupDto(titleZh: '拗音', columns: 3, rows: [_row('c', 3)]),
];

Future<void> _pumpChart(WidgetTester tester, double width) {
  final backend = FakeBackend();
  backend.kana.chartStub.returns(_groups());
  return pumpApp(
    tester,
    backend: backend,
    width: width,
    settings: settingsFixture(),
    child: const KanaChartScreen(),
  );
}

void main() {
  testWidgets('K1 寬螢幕把分區排成兩欄，格子不放大', (tester) async {
    await _pumpChart(tester, 768);

    expect(
      tester.getSize(find.byType(KanaCell).first).width,
      lessThanOrEqualTo(72),
    );
    expect(
      tester.getTopLeft(find.text('拗音')).dx,
      greaterThan(tester.getTopLeft(find.text('清音')).dx + 300),
    );
  });

  testWidgets('K1 窄版維持單欄、格子填滿內容寬', (tester) async {
    await _pumpChart(tester, 375);

    expect(tester.getSize(find.byType(KanaCell).first).width, greaterThan(60));
    expect(
      tester.getTopLeft(find.text('拗音')).dy,
      greaterThan(tester.getTopLeft(find.text('清音')).dy + 100),
    );
  });

  testWidgets('K1 的返回和其他頁一樣有箭頭', (tester) async {
    await _pumpChart(tester, 375);

    expect(find.byType(BackLine), findsOneWidget);
  });

  testWidgets('L2 假名區在寬螢幕維持小格', (tester) async {
    await pumpApp(
      tester,
      width: 768,
      child: LessonDetailSections.all(
        romajiMode: RomajiMode.shown,
        detail: LessonDetailDto(
          summary: const LessonSummaryDto(
            id: 'le.k02',
            stageId: 'st.s0',
            titleZh: 'か行',
            canDoZh: '',
            status: LessonStatus.current,
          ),
          kana: [kanaCellFixture()],
          rules: const [],
          words: const [],
          grammar: const [],
          integrationDaysDone: 0,
          integrationDaysNeeded: 0,
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(KanaCell).first).width,
      lessThanOrEqualTo(72),
    );
  });
}
