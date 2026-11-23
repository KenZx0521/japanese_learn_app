import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/features/quiz/question_policy.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import 'quiz_fixtures.dart';

const _lessonLess = PeekDto(refId: 'vo.neko', title: '猫', summaryZh: '貓');

LessonSummaryDto _lesson(String id) => LessonSummaryDto(
  id: id,
  stageId: 'st.1',
  titleZh: id,
  canDoZh: '',
  status: LessonStatus.notStarted,
);

Future<DisplayPolicyDto> _resolve(FakeBackend backend, String? fallback) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: repositoryOverrides(backend.repositories),
  );
  addTearDown(container.dispose);
  final key = (refFixture(QuestionType.recog), fallback);
  final subscription = container.listen(questionPolicyProvider(key), (_, _) {});
  addTearDown(subscription.close);
  return container.read(questionPolicyProvider(key).future);
}

String _askedLesson(FakeBackend backend) =>
    (backend.settings.displayPolicyStub.calls.single[0] as DisplayContext)
        .lessonId;

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.peek.peekStub.returns(_lessonLess);
  });

  test('呼叫端有給 fallback 時直接用，不查計畫', () async {
    await _resolve(backend, 'le.l03');
    expect(_askedLesson(backend), 'le.l03');
    expect(backend.plan.viewStub.calls, isEmpty);
  });

  test('沒給 fallback 時用計畫目前的課', () async {
    backend.plan.viewStub.returns(planViewFixture(currentLessonId: 'le.l07'));
    await _resolve(backend, null);
    expect(_askedLesson(backend), 'le.l07');
  });

  test('游標走完全部課時，用最後一個 L 課', () async {
    backend.plan.viewStub.returns(planViewFixture(currentLessonId: null));
    backend.course.overviewStub.returns(
      CourseOverviewDto(
        contentStage: ContentStage.p0A,
        stages: const [],
        lessons: [_lesson('le.k01'), _lesson('le.l02'), _lesson('le.k19')],
        notesAvailable: false,
      ),
    );
    await _resolve(backend, null);
    expect(_askedLesson(backend), 'le.l02');
  });

  test('沒有計畫也不擋作答', () async {
    backend.plan.viewStub.throws(const NoPlanFailure());
    backend.settings.displayPolicyStub.throws(
      const NotFoundFailure(detail: 'lesson'),
    );
    expect(await _resolve(backend, null), fallbackQuestionPolicy);
  });

  test('peek 失敗時退回 fallback 的課', () async {
    backend.peek.peekStub.throws(const StorageFailure());
    await _resolve(backend, 'le.l04');
    expect(_askedLesson(backend), 'le.l04');
  });
}
