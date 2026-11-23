// 所有領域的假後端。用法：
//   final backend = FakeBackend();
//   backend.today.todayStub.returns(todayFixture());
//   backend.vocab.detailStub.throws(const NotFoundFailure());
//   await pumpApp(tester, backend: backend, tts: FakeTtsEngine(), child: MyScreen());
//   expect(backend.today.todayStub.calls.single, [true]);
import 'dart:async';

import 'package:japanese_learn_app/core/backend/first_run_marker.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/repositories.dart';

import 'fixtures.dart';

/// 單一方法的替身：記錄參數，回傳可替換的結果。
final class Stub<R> {
  Stub(this._name, this._responder);

  /// 沒有預設資料的方法：呼叫時才丟出清楚的錯誤。
  factory Stub.unset(String name) =>
      Stub<R>(name, (_) => throw StateError('FakeBackend：$name 尚未設定回傳值'));

  final String _name;
  FutureOr<R> Function(List<Object?> args) _responder;
  final calls = <List<Object?>>[];

  /// 設定後呼叫會卡住，直到 Completer 完成（測載入狀態、先後順序）。
  Future<void>? gate;

  String get name => _name;

  void returns(R value) => _responder = (_) => value;
  void answers(FutureOr<R> Function(List<Object?> args) responder) =>
      _responder = responder;
  void throws(Object error) => _responder = (_) => throw error;

  Future<R> call(List<Object?> args) async {
    calls.add(args);
    final pending = gate;
    if (pending != null) await pending;
    return _responder(args);
  }
}

final class FakeTodayRepository implements TodayRepository {
  final todayStub = Stub<TodayViewDto>('today', (_) => todayFixture());
  final completeTaskStub = Stub<TodayViewDto>(
    'completeTask',
    (_) => todayFixture(),
  );
  final learnMoreStub = Stub<TodayViewDto>('learnMore', (_) => todayFixture());
  final newContentStub = Stub<NewContentSessionDto>.unset('newContent');
  final listenSessionStub = Stub<List<QuestionDto>>(
    'listenSession',
    (_) => const [],
  );

  @override
  Future<TodayViewDto> today(bool audio) => todayStub([audio]);
  @override
  Future<TodayViewDto> completeTask(String key, int durationMs, bool audio) =>
      completeTaskStub([key, durationMs, audio]);
  @override
  Future<TodayViewDto> learnMore(bool audio) => learnMoreStub([audio]);
  @override
  Future<NewContentSessionDto> newContent(String key, int seed, bool audio) =>
      newContentStub([key, seed, audio]);
  @override
  Future<List<QuestionDto>> listenSession(String key, int seed, bool audio) =>
      listenSessionStub([key, seed, audio]);
}

final class FakeCourseRepository implements CourseRepository {
  final overviewStub = Stub<CourseOverviewDto>(
    'overview',
    (_) => courseOverviewFixture(),
  );
  final lessonStub = Stub<LessonDetailDto>.unset('lesson');

  @override
  Future<CourseOverviewDto> overview() => overviewStub(const []);
  @override
  Future<LessonDetailDto> lesson(String id) => lessonStub([id]);
}

final class FakeKanaRepository implements KanaRepository {
  final chartStub = Stub<List<KanaGroupDto>>('chart', (_) => const []);
  final detailStub = Stub<KanaDetailDto>.unset('kana.detail');
  final ruleCardStub = Stub<RuleCardDto>.unset('kana.ruleCard');
  final sessionStub = Stub<List<QuestionDto>>('kana.session', (_) => const []);
  final submitStub = Stub<KanaSubmitResultDto>.unset('kana.submit');

  @override
  Future<List<KanaGroupDto>> chart(KanaScript script) => chartStub([script]);
  @override
  Future<KanaDetailDto> detail(String id) => detailStub([id]);
  @override
  Future<RuleCardDto> ruleCard(String id) => ruleCardStub([id]);
  @override
  Future<List<QuestionDto>> session(String lessonId, int seed, bool audio) =>
      sessionStub([lessonId, seed, audio]);
  @override
  Future<KanaSubmitResultDto> submit(
    QuestionRefDto reference,
    AnswerPayload response,
    int durationMs,
  ) => submitStub([reference, response, durationMs]);
}

final class FakeVocabRepository implements VocabRepository {
  final topicsStub = Stub<List<TopicDto>>('topics', (_) => const []);
  final pageStub = Stub<VocabPageDto>.unset('vocab.page');
  final searchStub = Stub<List<VocabSummaryDto>>('search', (_) => const []);
  final detailStub = Stub<VocabDetailDto>.unset('vocab.detail');
  final setFlagsStub = Stub<VocabSummaryDto>.unset('setFlags');

  @override
  Future<List<TopicDto>> topics() => topicsStub(const []);
  @override
  Future<VocabPageDto> page(VocabFilterDto filter, int offset, int limit) =>
      pageStub([filter, offset, limit]);
  @override
  Future<List<VocabSummaryDto>> search(String query, int limit) =>
      searchStub([query, limit]);
  @override
  Future<VocabDetailDto> detail(String id) => detailStub([id]);
  @override
  Future<VocabSummaryDto> setFlags(String id, VocabFlagsDto flags) =>
      setFlagsStub([id, flags]);
}

final class FakeReviewRepository implements ReviewRepository {
  final summaryStub = Stub<SessionSummaryDto>.unset('review.summary');
  final nextStub = Stub<SessionNextDto>(
    'review.next',
    (_) => const SessionNextDto.done(),
  );
  final submitStub = Stub<AnswerResultDto>.unset('review.submit');

  @override
  Future<SessionSummaryDto> summary(bool audio) => summaryStub([audio]);
  @override
  Future<SessionNextDto> next(int seed, bool audio) => nextStub([seed, audio]);
  @override
  Future<AnswerResultDto> submit(AnswerDto answer) => submitStub([answer]);
}

final class FakeGrammarRepository implements GrammarRepository {
  final listStub = Stub<List<GrammarSummaryDto>>(
    'grammar.list',
    (_) => const [],
  );
  final detailStub = Stub<GrammarDetailDto>.unset('grammar.detail');

  @override
  Future<List<GrammarSummaryDto>> list({String? stage, String? query}) =>
      listStub([stage, query]);
  @override
  Future<GrammarDetailDto> detail(String id) => detailStub([id]);
}

final class FakeNoteRepository implements NoteRepository {
  final listStub = Stub<List<NoteDto>>('note.list', (_) => const []);

  @override
  Future<List<NoteDto>> list(NoteKind kind) => listStub([kind]);
}

final class FakeDrillRepository implements DrillRepository {
  final sessionStub = Stub<List<QuestionDto>>('drill.session', (_) => const []);
  final gradeStub = Stub<DrillResultDto>.unset('drill.grade');
  final checkpointStartStub = Stub<List<QuestionDto>>(
    'checkpointStart',
    (_) => const [],
  );
  final checkpointFinishStub = Stub<CheckpointResultDto>.unset(
    'checkpointFinish',
  );
  final checkpointDismissStub = Stub<TodayViewDto>(
    'checkpointDismiss',
    (_) => todayFixture(),
  );

  @override
  Future<List<QuestionDto>> session(
    DrillFilterDto filter,
    int seed,
    bool audio,
  ) => sessionStub([filter, seed, audio]);
  @override
  Future<DrillResultDto> grade(
    QuestionRefDto reference,
    AnswerPayload response,
  ) => gradeStub([reference, response]);
  @override
  Future<List<QuestionDto>> checkpointStart(String id, int seed, bool audio) =>
      checkpointStartStub([id, seed, audio]);
  @override
  Future<CheckpointResultDto> checkpointFinish(
    String id,
    List<AnswerDto> answers,
  ) => checkpointFinishStub([id, answers]);
  @override
  Future<TodayViewDto> checkpointDismiss(String id, bool audio) =>
      checkpointDismissStub([id, audio]);
}

final class FakeListeningRepository implements ListeningRepository {
  final soundGroupsStub = Stub<List<SoundGroupDto>>(
    'soundGroups',
    (_) => const [],
  );
  final dialoguesStub = Stub<List<DialogueSummaryDto>>(
    'dialogues',
    (_) => const [],
  );
  final dialogueStub = Stub<DialogueDto>.unset('dialogue');

  @override
  Future<List<SoundGroupDto>> soundGroups() => soundGroupsStub(const []);
  @override
  Future<List<DialogueSummaryDto>> dialogues() => dialoguesStub(const []);
  @override
  Future<DialogueDto> dialogue(String id) => dialogueStub([id]);
}

final class FakePlanRepository implements PlanRepository {
  final viewStub = Stub<PlanViewDto>('plan.view', (_) => planViewFixture());
  final previewStub = Stub<PlanViewDto>(
    'plan.preview',
    (_) => planViewFixture(),
  );
  final createStub = Stub<PlanViewDto>('plan.create', (_) => planViewFixture());
  final updateStub = Stub<PlanViewDto>('plan.update', (_) => planViewFixture());
  final calendarStub = Stub<List<CalendarDayDto>>(
    'plan.calendar',
    (_) => const [],
  );
  final statsStub = Stub<StatsDto>('plan.stats', (_) => statsFixture());
  final activityStub = Stub<List<DayActivityDto>>(
    'plan.activity',
    (_) => const [],
  );

  @override
  Future<PlanViewDto> view() => viewStub(const []);
  @override
  Future<PlanViewDto> preview(PlanInputDto input) => previewStub([input]);
  @override
  Future<PlanViewDto> create(PlanInputDto input) => createStub([input]);
  @override
  Future<PlanViewDto> update(PlanInputDto input) => updateStub([input]);
  @override
  Future<List<CalendarDayDto>> calendar(int weeks) => calendarStub([weeks]);
  @override
  Future<StatsDto> stats() => statsStub(const []);
  @override
  Future<List<DayActivityDto>> activity(String from, String to) =>
      activityStub([from, to]);
}

final class FakeSettingsRepository implements SettingsRepository {
  SettingsDto current = settingsFixture();

  late final loadStub = Stub<SettingsDto>('settings.load', (_) => current);
  late final patchStub = Stub<SettingsDto>('settings.patch', (args) {
    current = applyPatch(current, args.single! as SettingsPatchDto);
    return current;
  });
  final displayPolicyStub = Stub<DisplayPolicyDto>(
    'settings.displayPolicy',
    (_) => displayPolicyFixture(),
  );
  final resetAllStub = Stub<void>('settings.resetAll', (_) {});

  @override
  Future<SettingsDto> load() => loadStub(const []);
  @override
  Future<SettingsDto> patch(SettingsPatchDto patch) => patchStub([patch]);
  @override
  Future<DisplayPolicyDto> displayPolicy(DisplayContext context) =>
      displayPolicyStub([context]);
  @override
  Future<void> resetAll() => resetAllStub(const []);
}

final class FakePeekRepository implements ContentPeekRepository {
  final peekStub = Stub<PeekDto>.unset('peek');

  @override
  Future<PeekDto> peek(String refId) => peekStub([refId]);
}

final class FakeClockRepository implements ClockRepository {
  final setUtcOffsetStub = Stub<void>('setUtcOffset', (_) {});

  @override
  Future<void> setUtcOffset(int minutes) => setUtcOffsetStub([minutes]);
}

final class FakeFirstRunMarker implements FirstRunMarker {
  bool flag = false;

  /// 設定後 `delete` 卡住，直到完成（測連點）。
  Future<void>? deleteGate;

  @override
  Future<bool> exists() async => flag;
  @override
  Future<void> create() async => flag = true;
  @override
  Future<void> delete() async {
    final gate = deleteGate;
    if (gate != null) await gate;
    flag = false;
  }
}

/// 羅馬字→假名與 `{ja:…}` 解析的假實作，夠 widget test 用。
final class FakeTextTools implements TextTools {
  const FakeTextTools();

  static final _marker = RegExp(r'\{ja:([^{}|]*)(?:\|([^{}]*))?\}');

  @override
  String romajiInputPreview(String input) => input;

  @override
  String? romanizeReading(String reading, ReadingMode mode) => reading;

  @override
  List<MixedSpanDto> parseMixedText(String input) {
    final spans = <MixedSpanDto>[];
    var cursor = 0;
    for (final match in _marker.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(MixedSpanDto.zh(text: input.substring(cursor, match.start)));
      }
      final text = match.group(1)!;
      spans.add(
        MixedSpanDto.ja(
          text: text,
          ruby: [RubyPartDto(base: text, ruby: match.group(2))],
        ),
      );
      cursor = match.end;
    }
    if (cursor < input.length) {
      spans.add(MixedSpanDto.zh(text: input.substring(cursor)));
    }
    return spans;
  }
}

/// 組合全部領域，`repositories` 給 `repositoryOverrides` 用。
final class FakeBackend {
  FakeBackend();

  final today = FakeTodayRepository();
  final course = FakeCourseRepository();
  final kana = FakeKanaRepository();
  final vocab = FakeVocabRepository();
  final review = FakeReviewRepository();
  final grammar = FakeGrammarRepository();
  final notes = FakeNoteRepository();
  final drills = FakeDrillRepository();
  final listening = FakeListeningRepository();
  final plan = FakePlanRepository();
  final settings = FakeSettingsRepository();
  final peek = FakePeekRepository();
  final clock = FakeClockRepository();
  final firstRunMarker = FakeFirstRunMarker();
  final textTools = const FakeTextTools();

  BackendRepositories get repositories => BackendRepositories(
    today: today,
    course: course,
    kana: kana,
    vocab: vocab,
    review: review,
    grammar: grammar,
    notes: notes,
    drills: drills,
    listening: listening,
    plan: plan,
    settings: settings,
    peek: peek,
    clock: clock,
    textTools: textTools,
  );
}
