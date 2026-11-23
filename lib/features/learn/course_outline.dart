import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/course_groups.dart';
import '../../core/backend/frb/dto.dart';

// L1 的課程結構，純函式。課程順序由 Rust 依 `course.order` 排好（假名課與主線課
// 交錯），這裡只分組，不重新排序。

const _kanaPrefix = 'le.k';
const _katakanaPrefix = 'le.kk';

/// 假名課（`le.k01`、`le.kk01`）；主線課是 `le.l01`。
bool isKanaLesson(String lessonId) => lessonId.startsWith(_kanaPrefix);

/// 學完或略過：游標都已經過了。
bool isLessonFinished(LessonSummaryDto lesson) => switch (lesson.status) {
  LessonStatus.done || LessonStatus.skipped => true,
  LessonStatus.current || LessonStatus.notStarted => false,
};

int _finishedCount(List<LessonSummaryDto> lessons) =>
    lessons.where(isLessonFinished).length;

/// 階段裡的一段。[title] 為 null 時整個階段只有這一段，不需要段落標題。
@immutable
final class LessonSection {
  const LessonSection({required this.lessons, this.title, this.note});

  final List<LessonSummaryDto> lessons;
  final String? title;
  final String? note;

  int get finished => _finishedCount(lessons);

  bool holds(String? lessonId) =>
      lessonId != null && lessons.any((lesson) => lesson.id == lessonId);
}

@immutable
final class StageOutline {
  const StageOutline({required this.stage, required this.sections});

  final StageDto stage;
  final List<LessonSection> sections;

  int get total => sections.fold(0, (sum, s) => sum + s.lessons.length);
  int get finished => sections.fold(0, (sum, s) => sum + s.finished);
}

List<LessonSection> _sectionsOf(List<LessonSummaryDto> lessons) {
  bool isKatakana(LessonSummaryDto l) => l.id.startsWith(_katakanaPrefix);
  bool isHiragana(LessonSummaryDto l) => isKanaLesson(l.id) && !isKatakana(l);

  final hiragana = lessons.where(isHiragana).toList();
  final katakana = lessons.where(isKatakana).toList();
  if (hiragana.isEmpty || katakana.isEmpty) {
    return [LessonSection(lessons: lessons)];
  }
  return [
    LessonSection(title: '平假名與發音規則', lessons: hiragana),
    LessonSection(title: '片假名', note: '和主線課輪流學', lessons: katakana),
  ];
}

/// 依階段分組；沒有課的階段不出現（O7）。
List<StageOutline> courseOutline(CourseOverviewDto overview) => [
  for (final group in groupByStage(
    overview.lessons,
    overview.stages,
    (lesson) => lesson.stageId,
  ))
    StageOutline(stage: group.stage, sections: _sectionsOf(group.items)),
];

/// [lessonId] 之後第一個還沒走過的課。
LessonSummaryDto? lessonAfter(
  List<LessonSummaryDto> lessons,
  String? lessonId,
) {
  final index = lessons.indexWhere((lesson) => lesson.id == lessonId);
  if (index < 0) return null;
  return lessons
      .skip(index + 1)
      .where((lesson) => !isLessonFinished(lesson))
      .firstOrNull;
}

/// K2 的題目來自新字、易混字組與規則卡掛的演練。只有規則說明的課（K18、K19）
/// 沒有題目，進去只會看到「這批都熟了」，所以不提供入口。
bool canPracticeKana(LessonDetailDto detail) =>
    isKanaLesson(detail.summary.id) &&
    (detail.kana.isNotEmpty ||
        detail.rules.isEmpty ||
        detail.rules.any((rule) => rule.drillIds.isNotEmpty));
