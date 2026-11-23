import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';

FakeBackend settingsBackend({ContentStage stage = ContentStage.p0A}) {
  final backend = FakeBackend();
  backend.course.overviewStub.returns(
    CourseOverviewDto(
      contentStage: stage,
      stages: const [],
      lessons: const [],
      notesAvailable: false,
    ),
  );
  return backend;
}

SettingsPatchDto lastPatch(FakeBackend backend) =>
    backend.settings.patchStub.calls.last.single! as SettingsPatchDto;

Future<void> tapRow(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> selectOption(WidgetTester tester, String label) async {
  final option = find.text(label).last;
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}
