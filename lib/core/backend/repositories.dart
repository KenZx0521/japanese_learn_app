// Repository 只包函式，DTO 直接用（architecture §5.3）。方法與 Rust API 一一對應。
import 'package:material_ui/material_ui.dart' show immutable;

import 'frb/dto.dart';

abstract interface class TodayRepository {
  Future<TodayViewDto> today(bool audio);
  Future<TodayViewDto> completeTask(String key, int durationMs, bool audio);
  Future<TodayViewDto> learnMore(bool audio);
  Future<NewContentSessionDto> newContent(String key, int seed, bool audio);
  Future<List<QuestionDto>> listenSession(String key, int seed, bool audio);
}

abstract interface class CourseRepository {
  Future<CourseOverviewDto> overview();
  Future<LessonDetailDto> lesson(String id);
}

abstract interface class KanaRepository {
  Future<List<KanaGroupDto>> chart(KanaScript script);
  Future<KanaDetailDto> detail(String id);
  Future<RuleCardDto> ruleCard(String id);
  Future<List<QuestionDto>> session(String lessonId, int seed, bool audio);
  Future<KanaSubmitResultDto> submit(
    QuestionRefDto reference,
    AnswerPayload response,
    int durationMs,
  );
}

abstract interface class VocabRepository {
  Future<List<TopicDto>> topics();
  Future<VocabPageDto> page(VocabFilterDto filter, int offset, int limit);
  Future<List<VocabSummaryDto>> search(String query, int limit);
  Future<VocabDetailDto> detail(String id);
  Future<VocabSummaryDto> setFlags(String id, VocabFlagsDto flags);
}

abstract interface class ReviewRepository {
  Future<SessionSummaryDto> summary(bool audio);
  Future<SessionNextDto> next(int seed, bool audio);
  Future<AnswerResultDto> submit(AnswerDto answer);
}

abstract interface class GrammarRepository {
  Future<List<GrammarSummaryDto>> list({String? stage, String? query});
  Future<GrammarDetailDto> detail(String id);
}

abstract interface class NoteRepository {
  Future<List<NoteDto>> list(NoteKind kind);
}

abstract interface class DrillRepository {
  Future<List<QuestionDto>> session(
    DrillFilterDto filter,
    int seed,
    bool audio,
  );
  Future<DrillResultDto> grade(
    QuestionRefDto reference,
    AnswerPayload response,
  );
  Future<List<QuestionDto>> checkpointStart(String id, int seed, bool audio);
  Future<CheckpointResultDto> checkpointFinish(
    String id,
    List<AnswerDto> answers,
  );
  Future<TodayViewDto> checkpointDismiss(String id, bool audio);
}

abstract interface class ListeningRepository {
  Future<List<SoundGroupDto>> soundGroups();
  Future<List<DialogueSummaryDto>> dialogues();
  Future<DialogueDto> dialogue(String id);
}

abstract interface class PlanRepository {
  Future<PlanViewDto> view();
  Future<PlanViewDto> preview(PlanInputDto input);
  Future<PlanViewDto> create(PlanInputDto input);
  Future<PlanViewDto> update(PlanInputDto input);
  Future<List<CalendarDayDto>> calendar(int weeks);
  Future<StatsDto> stats();
  Future<List<DayActivityDto>> activity(String from, String to);
}

abstract interface class SettingsRepository {
  Future<SettingsDto> load();
  Future<SettingsDto> patch(SettingsPatchDto patch);
  Future<DisplayPolicyDto> displayPolicy(DisplayContext context);
  Future<void> resetAll();
}

abstract interface class ContentPeekRepository {
  Future<PeekDto> peek(String refId);
}

/// `set_utc_offset`：`onResume` 時校正時區（跨日、旅行）。
abstract interface class ClockRepository {
  Future<void> setUtcOffset(int minutes);
}

/// `#[frb(sync)]` 的工具函式。放在 provider 上，測試注入假實作（§5.3）。
abstract interface class TextTools {
  String romajiInputPreview(String input);
  String? romanizeReading(String reading, ReadingMode mode);
  List<MixedSpanDto> parseMixedText(String input);
}

/// 一次注入全部領域的 repository：真實後端與 fake 都產生同一個形狀。
@immutable
final class BackendRepositories {
  const BackendRepositories({
    required this.today,
    required this.course,
    required this.kana,
    required this.vocab,
    required this.review,
    required this.grammar,
    required this.notes,
    required this.drills,
    required this.listening,
    required this.plan,
    required this.settings,
    required this.peek,
    required this.clock,
    required this.textTools,
  });

  final TodayRepository today;
  final CourseRepository course;
  final KanaRepository kana;
  final VocabRepository vocab;
  final ReviewRepository review;
  final GrammarRepository grammar;
  final NoteRepository notes;
  final DrillRepository drills;
  final ListeningRepository listening;
  final PlanRepository plan;
  final SettingsRepository settings;
  final ContentPeekRepository peek;
  final ClockRepository clock;
  final TextTools textTools;
}
