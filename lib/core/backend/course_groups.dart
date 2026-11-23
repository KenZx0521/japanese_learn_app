import 'frb/dto.dart';

/// 一個階段與其項目，順序與呼叫端傳入的相同。
typedef StageGroup<T> = ({StageDto stage, List<T> items});

/// 依 [stages] 的順序分組。沒有項目的階段不出現，所以 `p0a` 不會露出尚未發布的
/// 階段名稱（O7）。
List<StageGroup<T>> groupByStage<T>(
  List<T> items,
  List<StageDto> stages,
  String Function(T item) stageIdOf,
) => [
  for (final stage in stages)
    if (items.where((item) => stageIdOf(item) == stage.id).toList()
        case final members when members.isNotEmpty)
      (stage: stage, items: members),
];

/// 課的可讀名稱，依 `rust/content/course.json` 的課 id 規則：主線課 `le.l05` →
/// 「第 5 課」、平假名課 `le.k03` →「平假名第 3 課」、片假名課 `le.kk02` →
/// 「片假名第 2 課」。無法辨識的 id 原樣回傳，畫面上至少有東西可以對照。
String lessonNumberLabel(String lessonId) {
  for (final (pattern, prefix) in _lessonNamePatterns) {
    final digits = pattern.firstMatch(lessonId)?.group(1);
    if (digits != null) return '$prefix第 ${int.parse(digits)} 課';
  }
  return lessonId;
}

/// 列表的課名：主線課是「課次＋課名」，假名課的課名（「{ja:か}行」）已說明內容，只回課名。
String lessonHeadline(LessonSummaryDto lesson) => isMainLesson(lesson.id)
    ? '${lessonNumberLabel(lesson.id)}  ${lesson.titleZh}'
    : lesson.titleZh;

/// 主線課（`le.lNN`）才有句型、對話與 can-do 第二行；假名課沒有。
bool isMainLesson(String lessonId) => _mainLesson.hasMatch(lessonId);

final _mainLesson = RegExp(r'^le\.l(\d+)$');

final _lessonNamePatterns = [
  (_mainLesson, ''),
  (RegExp(r'^le\.kk(\d+)$'), '片假名'),
  (RegExp(r'^le\.k(\d+)$'), '平假名'),
];
