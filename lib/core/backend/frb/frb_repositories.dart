// lib/src/rust 的唯一進入點（architecture §5.1）。每個方法都經過 guardBackend。
import 'package:japanese_learn_app/src/rust/api/core.dart' show AppCore;
import 'package:japanese_learn_app/src/rust/api/tools_api.dart' as tools;

import '../failures.dart';
import '../repositories.dart';
import 'dto.dart';

BackendRepositories frbRepositories(AppCore core) => BackendRepositories(
  today: FrbTodayRepository(core),
  course: FrbCourseRepository(core),
  kana: FrbKanaRepository(core),
  vocab: FrbVocabRepository(core),
  review: FrbReviewRepository(core),
  grammar: FrbGrammarRepository(core),
  notes: FrbNoteRepository(core),
  drills: FrbDrillRepository(core),
  listening: FrbListeningRepository(core),
  plan: FrbPlanRepository(core),
  settings: FrbSettingsRepository(core),
  peek: FrbPeekRepository(core),
  clock: FrbClockRepository(core),
  textTools: const FrbTextTools(),
);

final class FrbTodayRepository implements TodayRepository {
  const FrbTodayRepository(this._core);
  final AppCore _core;

  @override
  Future<TodayViewDto> today(bool audio) =>
      guardBackend(() => _core.todayView(audioAvailable: audio));

  @override
  Future<TodayViewDto> completeTask(String key, int durationMs, bool audio) =>
      guardBackend(
        () => _core.completeTask(
          taskKey: key,
          durationMs: durationMs,
          audioAvailable: audio,
        ),
      );

  @override
  Future<TodayViewDto> learnMore(bool audio) =>
      guardBackend(() => _core.learnMore(audioAvailable: audio));

  @override
  Future<NewContentSessionDto> newContent(String key, int seed, bool audio) =>
      guardBackend(
        () => _core.newContentSession(
          taskKey: key,
          sessionSeed: seed,
          audioAvailable: audio,
        ),
      );

  @override
  Future<List<QuestionDto>> listenSession(String key, int seed, bool audio) =>
      guardBackend(
        () => _core.listenSession(
          taskKey: key,
          sessionSeed: seed,
          audioAvailable: audio,
        ),
      );
}

final class FrbCourseRepository implements CourseRepository {
  const FrbCourseRepository(this._core);
  final AppCore _core;

  @override
  Future<CourseOverviewDto> overview() => guardBackend(_core.courseOverview);

  @override
  Future<LessonDetailDto> lesson(String id) =>
      guardBackend(() => _core.lessonDetail(lessonId: id));
}

final class FrbKanaRepository implements KanaRepository {
  const FrbKanaRepository(this._core);
  final AppCore _core;

  @override
  Future<List<KanaGroupDto>> chart(KanaScript script) =>
      guardBackend(() => _core.kanaChart(script: script));

  @override
  Future<KanaDetailDto> detail(String id) =>
      guardBackend(() => _core.kanaDetail(kanaId: id));

  @override
  Future<RuleCardDto> ruleCard(String id) =>
      guardBackend(() => _core.ruleCard(ruleId: id));

  @override
  Future<List<QuestionDto>> session(String lessonId, int seed, bool audio) =>
      guardBackend(
        () => _core.kanaSession(
          lessonId: lessonId,
          sessionSeed: seed,
          audioAvailable: audio,
        ),
      );

  @override
  Future<KanaSubmitResultDto> submit(
    QuestionRefDto reference,
    AnswerPayload response,
    int durationMs,
  ) => guardBackend(
    () => _core.kanaSubmit(
      reference: reference,
      response: response,
      durationMs: durationMs,
    ),
  );
}

final class FrbVocabRepository implements VocabRepository {
  const FrbVocabRepository(this._core);
  final AppCore _core;

  @override
  Future<List<TopicDto>> topics() => guardBackend(_core.vocabTopics);

  @override
  Future<VocabPageDto> page(VocabFilterDto filter, int offset, int limit) =>
      guardBackend(
        () => _core.vocabPage(filter: filter, offset: offset, limit: limit),
      );

  @override
  Future<List<VocabSummaryDto>> search(String query, int limit) =>
      guardBackend(() => _core.searchVocab(query: query, limit: limit));

  @override
  Future<VocabDetailDto> detail(String id) =>
      guardBackend(() => _core.vocabDetail(vocabId: id));

  @override
  Future<VocabSummaryDto> setFlags(String id, VocabFlagsDto flags) =>
      guardBackend(() => _core.setVocabFlags(vocabId: id, flags: flags));
}

final class FrbReviewRepository implements ReviewRepository {
  const FrbReviewRepository(this._core);
  final AppCore _core;

  @override
  Future<SessionSummaryDto> summary(bool audio) =>
      guardBackend(() => _core.sessionSummary(audioAvailable: audio));

  @override
  Future<SessionNextDto> next(int seed, bool audio) => guardBackend(
    () => _core.sessionNext(sessionSeed: seed, audioAvailable: audio),
  );

  @override
  Future<AnswerResultDto> submit(AnswerDto answer) =>
      guardBackend(() => _core.submitAnswer(answer: answer));
}

final class FrbGrammarRepository implements GrammarRepository {
  const FrbGrammarRepository(this._core);
  final AppCore _core;

  @override
  Future<List<GrammarSummaryDto>> list({String? stage, String? query}) =>
      guardBackend(() => _core.grammarList(stage: stage, query: query));

  @override
  Future<GrammarDetailDto> detail(String id) =>
      guardBackend(() => _core.grammarDetail(grammarId: id));
}

final class FrbNoteRepository implements NoteRepository {
  const FrbNoteRepository(this._core);
  final AppCore _core;

  @override
  Future<List<NoteDto>> list(NoteKind kind) =>
      guardBackend(() => _core.noteList(kind: kind));
}

final class FrbDrillRepository implements DrillRepository {
  const FrbDrillRepository(this._core);
  final AppCore _core;

  @override
  Future<List<QuestionDto>> session(
    DrillFilterDto filter,
    int seed,
    bool audio,
  ) => guardBackend(
    () => _core.drillSession(
      filter: filter,
      sessionSeed: seed,
      audioAvailable: audio,
    ),
  );

  @override
  Future<DrillResultDto> grade(
    QuestionRefDto reference,
    AnswerPayload response,
  ) => guardBackend(
    () => _core.gradeDrill(question: reference, response: response),
  );

  @override
  Future<List<QuestionDto>> checkpointStart(String id, int seed, bool audio) =>
      guardBackend(
        () => _core.checkpointStart(
          milestoneId: id,
          sessionSeed: seed,
          audioAvailable: audio,
        ),
      );

  @override
  Future<CheckpointResultDto> checkpointFinish(
    String id,
    List<AnswerDto> answers,
  ) => guardBackend(
    () => _core.checkpointFinish(milestoneId: id, answers: answers),
  );

  @override
  Future<TodayViewDto> checkpointDismiss(String id, bool audio) => guardBackend(
    () => _core.checkpointDismiss(milestoneId: id, audioAvailable: audio),
  );
}

final class FrbListeningRepository implements ListeningRepository {
  const FrbListeningRepository(this._core);
  final AppCore _core;

  @override
  Future<List<SoundGroupDto>> soundGroups() => guardBackend(_core.soundGroups);

  @override
  Future<List<DialogueSummaryDto>> dialogues() => guardBackend(_core.dialogues);

  @override
  Future<DialogueDto> dialogue(String id) =>
      guardBackend(() => _core.dialogueDetail(dialogueId: id));
}

final class FrbPlanRepository implements PlanRepository {
  const FrbPlanRepository(this._core);
  final AppCore _core;

  @override
  Future<PlanViewDto> view() => guardBackend(_core.planView);

  @override
  Future<PlanViewDto> preview(PlanInputDto input) =>
      guardBackend(() => _core.planPreview(input: input));

  @override
  Future<PlanViewDto> create(PlanInputDto input) =>
      guardBackend(() => _core.createPlan(input: input));

  @override
  Future<PlanViewDto> update(PlanInputDto input) =>
      guardBackend(() => _core.updatePlan(input: input));

  @override
  Future<List<CalendarDayDto>> calendar(int weeks) =>
      guardBackend(() => _core.calendar(weeks: weeks));

  @override
  Future<StatsDto> stats() => guardBackend(_core.statsOverview);

  @override
  Future<List<DayActivityDto>> activity(String from, String to) =>
      guardBackend(() => _core.activityRange(fromDate: from, toDate: to));
}

final class FrbSettingsRepository implements SettingsRepository {
  const FrbSettingsRepository(this._core);
  final AppCore _core;

  @override
  Future<SettingsDto> load() => guardBackend(_core.settings);

  @override
  Future<SettingsDto> patch(SettingsPatchDto patch) =>
      guardBackend(() => _core.updateSettings(patch: patch));

  @override
  Future<DisplayPolicyDto> displayPolicy(DisplayContext context) =>
      guardBackend(() => _core.displayPolicy(context: context));

  @override
  Future<void> resetAll() => guardBackend(_core.resetAll);
}

final class FrbPeekRepository implements ContentPeekRepository {
  const FrbPeekRepository(this._core);
  final AppCore _core;

  @override
  Future<PeekDto> peek(String refId) =>
      guardBackend(() => _core.peek(refId: refId));
}

final class FrbClockRepository implements ClockRepository {
  const FrbClockRepository(this._core);
  final AppCore _core;

  @override
  Future<void> setUtcOffset(int minutes) =>
      guardBackend(() => _core.setUtcOffset(minutes: minutes));
}

final class FrbTextTools implements TextTools {
  const FrbTextTools();

  @override
  String romajiInputPreview(String input) =>
      tools.romajiInputPreview(input: input);

  @override
  String? romanizeReading(String reading, ReadingMode mode) =>
      tools.romanizeReading(reading: reading, mode: mode);

  @override
  List<MixedSpanDto> parseMixedText(String input) =>
      tools.parseMixedText(input: input);
}
