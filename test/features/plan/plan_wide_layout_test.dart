import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/design/widgets/genko_grid.dart';
import 'package:japanese_learn_app/features/plan/adjust/plan_adjust_fields.dart';
import 'package:japanese_learn_app/features/plan/plan_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';
import 'plan_fixtures.dart';

FakeBackend _backend() {
  final backend = FakeBackend();
  final current = planView();
  backend.plan.viewStub.returns(current);
  backend.plan.previewStub.returns(current);
  backend.course.overviewStub.returns(overview());
  backend.plan.calendarStub.returns(fourWeeks());
  return backend;
}

void main() {
  testWidgets('寬螢幕的月曆列高有上限，格子不會像海報一樣', (tester) async {
    await pumpApp(
      tester,
      backend: _backend(),
      width: 768,
      child: const PlanScreen(),
    );

    final calendarGrid = find.byWidgetPredicate(
      (widget) => widget is GenkoGrid && widget.columns == 7,
    );
    final rows = (tester.widget<GenkoGrid>(calendarGrid).children.length / 7)
        .ceil();
    expect(tester.getSize(calendarGrid).height, lessThan(rows * 90 + 30));
  });

  testWidgets('320 寬時「10 分」不換行', (tester) async {
    await pumpApp(
      tester,
      width: 320,
      child: MinutesPicker(selected: 10, onChanged: (_) {}),
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.text('10 分'));
    expect(
      paragraph.size.height,
      lessThan(
        paragraph.getFullHeightForCaret(const TextPosition(offset: 0)) * 1.5,
      ),
    );
  });
}
