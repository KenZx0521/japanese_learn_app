// 真實資料截圖 QA 抓到的版面缺陷（320／375／768／1024）。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/genko_grid.dart';
import 'package:japanese_learn_app/design/widgets/kana_cell.dart';
import 'package:japanese_learn_app/design/widgets/speed_toggle.dart';
import 'package:japanese_learn_app/features/vocab/widgets/toggle_tag.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fixtures.dart';
import '../support/pump_app.dart';

Future<void> _pumpCell(WidgetTester tester, KanaCell cell) => pumpApp(
  tester,
  settings: settingsFixture(),
  child: Center(child: SizedBox.square(dimension: 64, child: cell)),
);

void main() {
  group('GenkoGrid 上限', () {
    Future<void> pumpGrid(WidgetTester tester, GenkoGrid grid) => pumpApp(
      tester,
      width: 720,
      child: Align(alignment: Alignment.topLeft, child: grid),
    );

    testWidgets('maxCell 限制格寬，格子不會隨內容寬放大', (tester) async {
      await pumpGrid(
        tester,
        const GenkoGrid(maxCell: 72, children: [SizedBox.expand()]),
      );

      expect(tester.getSize(find.byType(SizedBox).last), const Size(72, 72));
    });

    testWidgets('maxCellHeight 只限制列高，格寬仍填滿內容寬', (tester) async {
      await pumpGrid(
        tester,
        const GenkoGrid(maxCellHeight: 88, children: [SizedBox.expand()]),
      );

      expect(tester.getSize(find.byType(SizedBox).last), const Size(144, 88));
    });

    testWidgets('沒有上限時維持正方形格', (tester) async {
      await pumpGrid(tester, const GenkoGrid(children: [SizedBox.expand()]));

      expect(tester.getSize(find.byType(SizedBox).last), const Size(144, 144));
    });
  });

  group('KanaCell 狀態點', () {
    testWidgets('朱點在格子右上角，不是貼著字（會蓋住濁點）', (tester) async {
      await _pumpCell(
        tester,
        const KanaCell(
          kana: 'が',
          romaji: 'ga',
          status: KanaStatus.mastered,
          fastBadge: true,
        ),
      );

      final cell = tester.getTopRight(find.byType(KanaCell));
      final dots = find.descendant(
        of: find.byType(KanaCell),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      final right = dots.evaluate().map(
        (element) => tester.getTopRight(find.byWidget(element.widget)).dx,
      );
      expect(right.reduce((a, b) => a > b ? a : b), greaterThan(cell.dx - 6));
    });

    testWidgets('拗音兩個字不用單字字級，字之間留得下空隙', (tester) async {
      await _pumpCell(
        tester,
        const KanaCell(kana: 'きゃ', romaji: 'kya', status: KanaStatus.learning),
      );

      expect(
        tester.widget<Text>(find.text('きゃ')).style?.fontSize,
        lessThan(26),
      );
    });
  });

  testWidgets('SpeedToggle 放在撐滿的欄內不會被拉成整行', (tester) async {
    await pumpApp(
      tester,
      settings: settingsFixture(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SpeedToggle()],
      ),
    );

    expect(
      tester.getSize(find.text('1 倍')).width,
      lessThan(tester.getSize(find.byType(SpeedToggle)).width),
    );
    final box = tester.renderObject<RenderBox>(
      find
          .descendant(
            of: find.byType(SpeedToggle),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(box.size.width, lessThan(120));
  });

  testWidgets('ToggleTag 在 Wrap 裡依文字寬，不佔滿整行', (tester) async {
    await pumpApp(
      tester,
      child: Wrap(
        children: [ToggleTag(label: '收藏', value: false, onChanged: (_) {})],
      ),
    );

    expect(tester.getSize(find.byType(ToggleTag)).width, lessThan(120));
  });
}
